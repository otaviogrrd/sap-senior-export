REPORT zhr_senior_exp_1006.

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

  gv_filename = sy-datum && '_SENIOR_1006.csv'.

  gv_header = 'CODMOT;NOMMOT;TIPMOT;MTVALT;TPOMVT'.

*---------------------------------------------------------------------*
* Selecao de motivos (T530)
*---------------------------------------------------------------------*

  SELECT
    massg,   " Codigo motivo
    mgtxt,   " Descricao
    massn    " Tipo movimentacao
  INTO TABLE @DATA(gt_motivos)
  FROM t530t.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipmot TYPE c LENGTH 1,
    lv_mtvalt TYPE c LENGTH 1,
    lv_tpomvt TYPE c LENGTH 1.

  LOOP AT gt_motivos ASSIGNING FIELD-SYMBOL(<fs_mot>).

*---------------------------------------------------------------------*
* TIPMOT - Lista LTipMot
*---------------------------------------------------------------------*

    PERFORM f_conv_tipmot IN PROGRAM zhr_export_senior
      USING <fs_mot>-massg
      CHANGING lv_tipmot.

    IF lv_tipmot IS INITIAL.
      lv_tipmot = 'E'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* MTVALT - Lista LMtvAlt
*---------------------------------------------------------------------*

    PERFORM f_conv_mtvalt IN PROGRAM zhr_export_senior
      USING <fs_mot>-massg
      CHANGING lv_mtvalt.

    IF lv_mtvalt IS INITIAL.
      lv_mtvalt = '0'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* TPOMVT - Lista LTpoMvt
*---------------------------------------------------------------------*

    PERFORM f_conv_tpomvt IN PROGRAM zhr_export_senior
      USING <fs_mot>-massn
      CHANGING lv_tpomvt.

    IF lv_tpomvt IS INITIAL.
      lv_tpomvt = '0'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_mot>-massg     && ';' && " CODMOT
      <fs_mot>-mgtxt     && ';' && " NOMMOT
      lv_tipmot          && ';' && " TIPMOT
      lv_mtvalt          && ';' && " MTVALT
      lv_tpomvt.                   " TPOMVT

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
