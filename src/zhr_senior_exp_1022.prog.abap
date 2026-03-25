REPORT ZHR_SENIOR_EXP_1022.

PARAMETERS: p_file TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.  PERFORM f_exportar_dados.

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

  gv_filename = sy-datum && '_SENIOR_1022.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;INIETB;FIMETB;CODETB'.

*---------------------------------------------------------------------*
* SeleÃ§Ã£o (PA0598 + PA0001)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p598~begda,
    p598~endda,
    p598~dptype
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  INNER JOIN pa0598 AS p598
    ON p598~pernr = p1~pernr.

*---------------------------------------------------------------------*
* OrdenaÃ§Ã£o
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
    lv_inietb TYPE char10,
    lv_fimetb TYPE char10,
    lv_codetb TYPE c LENGTH 2.

  SORT gt_hist BY pernr begda endda dptype.
  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda endda dptype.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).
    DATA: lv_last_begda  TYPE begda,
          lv_last_endda  TYPE endda,
          lv_last_dptype TYPE pa0598-dptype.

    AT NEW pernr.
      CLEAR: lv_last_begda, lv_last_endda, lv_last_dptype.
    ENDAT.

    IF <fs_hist>-begda = lv_last_begda
     AND <fs_hist>-endda = lv_last_endda
     AND <fs_hist>-dptype = lv_last_dptype.
      CONTINUE.
    ENDIF.

    lv_last_begda  = <fs_hist>-begda.
    lv_last_endda  = <fs_hist>-endda.
    lv_last_dptype = <fs_hist>-dptype.


*---------------------------------------------------------------------*
* ConversÃµes
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-begda
      CHANGING lv_inietb.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-endda
      CHANGING lv_fimetb.

*---------------------------------------------------------------------*
* CÃ³digo Estabilidade
*---------------------------------------------------------------------*

    lv_codetb = <fs_hist>-dptype.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_inietb         && ';' && " INIETB
      lv_fimetb         && ';' && " FIMETB
      lv_codetb.                    " CODETB

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      default_extension = 'csv'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_fullpath IS NOT INITIAL.
    p_file = lv_fullpath.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  lv_fullpath = p_file.

  IF lv_fullpath IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_save_dialog
      EXPORTING
        default_extension = 'csv'
        default_file_name = pv_filename
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_fullpath IS INITIAL.
      MESSAGE 'Selecao do arquivo cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

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

  p_file = lv_fullpath.

ENDFORM.