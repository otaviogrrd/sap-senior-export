REPORT ZHR_SENIOR_EXP_1003.

PARAMETERS: p_file TYPE string LOWER CASE,
            p_head AS CHECKBOX DEFAULT 'X'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

DATA: gv_filename TYPE string,
      gv_header   TYPE string,
      gv_line     TYPE string,
      gt_file     TYPE STANDARD TABLE OF string,
      gv_count    TYPE i.

START-OF-SELECTION.

  PERFORM build_filename.
  PERFORM build_header.
  PERFORM get_data.
  WRITE: / 'Arquivo gerado:', gv_filename.
  WRITE: / 'Registros exportados:', gv_count.

FORM build_filename.
  DATA lv_date TYPE char8.
  DATA lv_time TYPE char6.
  lv_date = sy-datum.
  lv_time = sy-uzeit.
  IF p_file IS INITIAL.
    CONCATENATE 'SENIOR_1003_' lv_date '_' lv_time '.csv' INTO gv_filename.
  ELSE.
    gv_filename = p_file.
  ENDIF.
ENDFORM.

FORM build_header.
  gv_header = 'NUMEMP;CODCCU;CODCGO;DESCCGO;DTINICIO;DTFIM'.
ENDFORM.

FORM get_data.
  
  IF p_head = 'X'.
    APPEND gv_header TO gt_file.
  ENDIF.

  " TODO: implementar SELECT e mapeamento do layout
  " Exemplo:
  " CLEAR gv_line.
  " CONCATENATE 'VAL1' 'VAL2' INTO gv_line SEPARATED BY ';'.
  " APPEND gv_line TO gt_file.
  " ADD 1 TO gv_count.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.
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
      MESSAGE 'Selecao de arquivo cancelada.' TYPE 'E'.
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
