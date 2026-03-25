REPORT zhr_export_senior_1.

PARAMETERS:
  p_dir   TYPE rlgrap-filename LOWER CASE DEFAULT 'C:\Users\otavi\Documents\GitHub\sap-senior-export\src',
  p_test  AS CHECKBOX,
  p_fname TYPE rlgrap-filename LOWER CASE NO-DISPLAY,
  p_path  TYPE rlgrap-filename LOWER CASE NO-DISPLAY,
  p_tpath TYPE rlgrap-filename LOWER CASE NO-DISPLAY.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM f_select_dir.

START-OF-SELECTION.

  PERFORM f_prepare_input.
  PERFORM f_validate.
  PERFORM f_upload_all.

FORM f_select_dir.

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

FORM f_prepare_input.

  DATA lv_last TYPE c LENGTH 1.
  DATA lv_len TYPE i.

  IF p_dir IS INITIAL AND p_path IS NOT INITIAL.
    p_dir = p_path.

    IF p_dir IS NOT INITIAL.
      lv_len = strlen( p_dir ) - 1.
      IF lv_len >= 0.
        lv_last = p_dir+lv_len(1).
        IF lv_last <> '/' AND lv_last <> '\'.
          CONCATENATE p_dir '\' INTO p_dir.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.

FORM f_validate.

  DATA lv_last TYPE c LENGTH 1.
  DATA lv_len TYPE i.

  IF p_dir IS INITIAL.
    MESSAGE 'Informe o diretorio local.' TYPE 'E'.
  ENDIF.

  lv_len = strlen( p_dir ) - 1.
  IF lv_len >= 0.
    lv_last = p_dir+lv_len(1).
    IF lv_last <> '/' AND lv_last <> '\'.
      CONCATENATE p_dir '\' INTO p_dir.
    ENDIF.
  ENDIF.

ENDFORM.

FORM f_upload_one USING pv_file TYPE string.

  DATA:
    lt_source   TYPE STANDARD TABLE OF string,
    lt_report   TYPE STANDARD TABLE OF text255,
    lt_parts    TYPE STANDARD TABLE OF string,
    lt_objects  TYPE STANDARD TABLE OF dwinactiv,
    ls_object   TYPE dwinactiv,
    lv_file_in  TYPE string,
    lv_filename TYPE string,
    lv_program  TYPE progname,
    lv_part     TYPE string,
    lv_line     TYPE string.

  lv_file_in = pv_file.

  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING
      filename                = lv_file_in
      filetype                = 'ASC'
    TABLES
      data_tab                = lt_source
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      not_supported_by_gui    = 17
      error_no_gui            = 18
      OTHERS                  = 19.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao ler o arquivo local.' TYPE 'E'.
  ENDIF.

  lv_filename = pv_file.
  REPLACE ALL OCCURRENCES OF '\' IN lv_filename WITH '/'.
  SPLIT lv_filename AT '/' INTO TABLE lt_parts.
  READ TABLE lt_parts INTO lv_part INDEX lines( lt_parts ).
  lv_program = lv_part.
  REPLACE FIRST OCCURRENCE OF '.prog.abap' IN lv_program WITH ''.
  REPLACE FIRST OCCURRENCE OF '.abap' IN lv_program WITH ''.

  TRANSLATE lv_program TO UPPER CASE.

  IF lv_program NE 'ZHR_EXPORT_SENIOR'.
    IF lv_program NP 'ZHR_SENIOR_EXP_*'.
      MESSAGE 'O programa de destino deve ser ZHR_SENIOR_EXP_*.' TYPE 'E'.
    ENDIF.
  ENDIF.

  LOOP AT lt_source INTO lv_line.
    APPEND lv_line TO lt_report.
  ENDLOOP.

  IF p_test = 'X'.
    WRITE: / 'Programa:', lv_program.
    WRITE: / 'Arquivo:', pv_file.
    WRITE: / 'Linhas carregadas:', lines( lt_report ).
    ULINE.
    RETURN.
  ENDIF.

  INSERT REPORT lv_program FROM lt_report.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao gravar o report no repositorio SAP.' TYPE 'E'.
  ENDIF.

  CLEAR ls_object.
  ls_object-object   = 'PROG'.
  ls_object-obj_name = lv_program.
  APPEND ls_object TO lt_objects.

  CALL FUNCTION 'RS_WORKING_OBJECTS_ACTIVATE'
    TABLES
      objects                = lt_objects
    EXCEPTIONS
      excecution_error       = 1
      cancelled              = 2
      insert_into_corr_error = 3
      OTHERS                 = 4.

  IF sy-subrc <> 0.
    WRITE: / 'Programa gravado, mas houve erro na ativacao:', lv_program.
    WRITE: / 'Arquivo:', pv_file.
    ULINE.
    RETURN.
  ENDIF.

  WRITE: / 'Programa carregado e ativado:', lv_program.
  WRITE: / 'Arquivo:', pv_file.
  WRITE: / 'Linhas gravadas:', lines( lt_report ).
  ULINE.

ENDFORM.

FORM f_upload_all.

  DATA:
    lt_files TYPE filetable,
    ls_file  LIKE LINE OF lt_files,
    lv_dir   TYPE string,
    lv_file  TYPE string,
    lv_count TYPE i,
    lv_last  TYPE c LENGTH 1,
    lv_len   TYPE i.

  lv_dir = p_dir.
  REPLACE ALL OCCURRENCES OF '/' IN lv_dir WITH '\'.

  CALL METHOD cl_gui_frontend_services=>directory_list_files
    EXPORTING
      directory                   = lv_dir
      filter                      = 'zhr_senior_exp_*.prog.abap'
    CHANGING
      file_table                  = lt_files
      count                       = lv_count
    EXCEPTIONS
      cntl_error                  = 1
      directory_list_files_failed = 2
      wrong_parameter             = 3
      error_no_gui                = 4
      not_supported_by_gui        = 5
      OTHERS                      = 6.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao listar os arquivos do diretorio.' TYPE 'E'.
  ENDIF.

  IF lv_count IS INITIAL.
    MESSAGE 'Nenhum arquivo zhr_senior_exp_*.prog.abap encontrado.' TYPE 'E'.
  ENDIF.

  LOOP AT lt_files INTO ls_file.
    lv_file = lv_dir.
    lv_len = strlen( lv_file ) - 1.
    IF lv_len >= 0.
      lv_last = lv_file+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_file '\' INTO lv_file.
      ENDIF.
    ENDIF.
    CONCATENATE lv_file ls_file-filename INTO lv_file.
    PERFORM f_upload_one USING lv_file.
  ENDLOOP.

  CLEAR lt_files[].
  CALL METHOD cl_gui_frontend_services=>directory_list_files
    EXPORTING
      directory                   = lv_dir
      filter                      = 'ZHR_EXPORT_SENIOR.*prog.abap'
    CHANGING
      file_table                  = lt_files
      count                       = lv_count
    EXCEPTIONS
      cntl_error                  = 1
      directory_list_files_failed = 2
      wrong_parameter             = 3
      error_no_gui                = 4
      not_supported_by_gui        = 5
      OTHERS                      = 6.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao listar os arquivos do diretorio.' TYPE 'E'.
  ENDIF.

  IF lv_count IS INITIAL.
    MESSAGE 'ZHR_EXPORT_SENIOR não encontrado.' TYPE 'E'.
  ENDIF.

  LOOP AT lt_files INTO ls_file.
    lv_file = lv_dir.
    lv_len = strlen( lv_file ) - 1.
    IF lv_len >= 0.
      lv_last = lv_file+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_file '\' INTO lv_file.
      ENDIF.
    ENDIF.
    CONCATENATE lv_file ls_file-filename INTO lv_file.
    PERFORM f_upload_one USING lv_file.
  ENDLOOP.

ENDFORM.