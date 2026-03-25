REPORT zhr_senior_exp_1002.

DATA: gv_filename TYPE string,
      gv_header   TYPE string,
      gv_line     TYPE string,
      gt_file     TYPE STANDARD TABLE OF string,
      gv_count    TYPE i.
PARAMETERS: p_dir TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM f_selecionar_arquivo.


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
    CONCATENATE 'SENIOR_1002_' lv_date '_' lv_time '.csv' INTO gv_filename.
  ELSE.
    gv_filename = p_file.
  ENDIF.
ENDFORM.

FORM build_header.
  gv_header = 'NUMEMP;CODCCU;DESCCCU;NIVCCU;DTINICIO;DTFIM'.
ENDFORM.

FORM get_data.

    APPEND gv_header TO gt_file.

  " TODO: implementar SELECT e mapeamento do layout
  " Exemplo:
  " CLEAR gv_line.
  " CONCATENATE 'VAL1' 'VAL2' INTO gv_line SEPARATED BY ';'.
  " APPEND gv_line TO gt_file.
  " ADD 1 TO gv_count.

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