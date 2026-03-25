REPORT zhr_senior_exp_1038.

PARAMETERS: p_dir TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.

  PERFORM f_export.

FORM f_export.

  DATA: gv_filename TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

  gv_filename = sy-datum && '_1038.csv'.

  
  WRITE: / 'Layout 1038 gerado:', gv_filename.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

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
    p_dir = lv_folder.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_folder   TYPE string,
    lv_fullpath TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.

  lv_folder = p_dir.

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

  p_dir = lv_folder.

ENDFORM.
