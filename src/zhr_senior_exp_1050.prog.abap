REPORT ZHR_SENIOR_EXP_1050.

PARAMETERS: p_dir  TYPE string LOWER CASE,
            p_file TYPE string LOWER CASE.

DATA: gv_filename TYPE string,
      gv_header   TYPE string,
      gv_line     TYPE string,
      gv_count    TYPE i.

START-OF-SELECTION.
  PERFORM build_filename.
  PERFORM build_header.
  PERFORM get_data.
  WRITE: / 'Arquivo gerado:', gv_filename.
  WRITE: / 'Registros exportados:', gv_count.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM f_select_directory.

FORM build_filename.
  DATA lv_date TYPE char8.
  DATA lv_time TYPE char6.
  DATA lv_leng TYPE i.
  lv_date = sy-datum.
  lv_time = sy-uzeit.
  gv_filename = p_dir.
  IF gv_filename IS INITIAL.
    PERFORM f_select_directory.
    gv_filename = p_dir.
  ENDIF.
  lv_leng = strlen( gv_filename ) - 1.
  IF gv_filename+lv_leng(1) <> '/' AND gv_filename+lv_leng(1) <> '\'.
    CONCATENATE gv_filename '\' INTO gv_filename.
  ENDIF.
  IF p_file IS INITIAL.
    CONCATENATE gv_filename 'SENIOR_1050_' lv_date '_' lv_time '.csv' INTO gv_filename.
  ELSE.
    CONCATENATE gv_filename p_file INTO gv_filename.
  ENDIF.
ENDFORM.

FORM build_header.
  gv_header = 'CODHOR;DESHOR;TURHOR;TIPHOR;FLEESO;TIPINT'.
ENDFORM.

FORM get_data.
  DATA lt_file TYPE STANDARD TABLE OF string.

  APPEND gv_header TO lt_file.

  " TODO: implementar SELECT e mapeamento do layout
  " Exemplo:
  " CLEAR gv_line.
  " CONCATENATE 'VAL1' 'VAL2' INTO gv_line SEPARATED BY ';'.
  " APPEND gv_line TO lt_file.
  " ADD 1 TO gv_count.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = gv_filename
      filetype = 'ASC'
    TABLES
      data_tab = lt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM f_select_directory.

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
