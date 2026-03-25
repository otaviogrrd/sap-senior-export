REPORT zhr_senior_exp_1021.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1021.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;EMPATU;CADATU;CODFIL;TIPADM;FICREG;ADMESO'.

*---------------------------------------------------------------------*
* Sele??o (PA0001 + PA0000)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p1~begda,
    p1~werks,
    p1~btrtl,
    p0~massn,
    p0~massg
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  LEFT JOIN pa0000 AS p0
    ON p0~pernr = p1~pernr
   AND p0~begda = p1~begda.

*---------------------------------------------------------------------*
* Ordena??o
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datalt TYPE char10,
    lv_tipadm TYPE c LENGTH 2,
    lv_admeso TYPE c LENGTH 1,
    lv_ficreg TYPE string.

  SORT gt_hist BY pernr begda werks btrtl.

  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda werks btrtl.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).
    DATA: lv_last_werks TYPE werks_d,
          lv_last_btrtl TYPE btrtl.

    AT NEW pernr.
      CLEAR: lv_last_werks, lv_last_btrtl.
    ENDAT.

    IF <fs_hist>-werks = lv_last_werks
     AND <fs_hist>-btrtl = lv_last_btrtl.
      CONTINUE.
    ENDIF.

    lv_last_werks = <fs_hist>-werks.
    lv_last_btrtl = <fs_hist>-btrtl.
*---------------------------------------------------------------------*
* Convers?es
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-begda
      CHANGING lv_datalt.

*---------------------------------------------------------------------*
* Tipo admiss?o (MASSN/MASSG)
*---------------------------------------------------------------------*

    " TIPADM (2 posi??es)
    PERFORM f_conv_tipadm IN PROGRAM zhr_export_senior
      USING <fs_hist>-massn <fs_hist>-massg
      CHANGING lv_tipadm.

    " ADMESO (1 posi??o)
    PERFORM f_conv_tipadm IN PROGRAM zhr_export_senior
      USING <fs_hist>-massn <fs_hist>-massg
      CHANGING lv_tipadm.

*---------------------------------------------------------------------*
* FICREG (fallback)
*---------------------------------------------------------------------*
    lv_ficreg = <fs_hist>-pernr.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      <fs_hist>-werks   && ';' && " EMPATU
      <fs_hist>-btrtl   && ';' && " CADATU
      <fs_hist>-btrtl   && ';' && " CODFIL
      lv_tipadm         && ';' && " TIPADM
      lv_ficreg         && ';' && " FICREG
      lv_admeso.                    " ADMESO

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA lv_folder TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_folder IS NOT INITIAL.
    p_locl = lv_folder.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_folder   TYPE string,
    lv_server   TYPE string,
    lv_fullpath TYPE string,
    lv_line     TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.

  lv_server = p_serv.

  IF lv_server IS NOT INITIAL.
    lv_len = strlen( lv_server ) - 1.
    IF lv_len >= 0.
      lv_last = lv_server+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_server '/' INTO lv_server.
      ENDIF.
    ENDIF.

    CONCATENATE lv_server pv_filename INTO lv_fullpath.

    OPEN DATASET lv_fullpath FOR OUTPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo no servidor.' TYPE 'E'.
    ENDIF.

    LOOP AT pt_file INTO lv_line.
      TRANSFER lv_line TO lv_fullpath.
    ENDLOOP.

    CLOSE DATASET lv_fullpath.
    p_serv = lv_server.
    RETURN.
  ENDIF.

  lv_folder = p_locl.

  IF lv_folder IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>directory_browse
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_folder IS INITIAL.
      MESSAGE 'Selecao de diretorio cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  lv_len = strlen( lv_folder ) - 1.
  IF lv_len >= 0.
    lv_last = lv_folder+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE lv_folder '\' INTO lv_folder.
    ENDIF.
  ENDIF.

  CONCATENATE lv_folder pv_filename INTO lv_fullpath.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

  p_locl = lv_folder.

ENDFORM.
