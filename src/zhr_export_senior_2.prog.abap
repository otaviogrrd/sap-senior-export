REPORT zhr_export_senior_2.

PARAMETERS:
  p_dir  TYPE string LOWER CASE,
  p_test AS CHECKBOX.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM f_select_directory.

START-OF-SELECTION.

  PERFORM f_validate.
  PERFORM f_normalize_directory.
  PERFORM f_backup_reports.

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

FORM f_validate.

  IF p_dir IS INITIAL.
    MESSAGE 'Informe o diretorio local de backup.' TYPE 'E'.
  ENDIF.

ENDFORM.

FORM f_normalize_directory.

  DATA lv_last TYPE c LENGTH 1.
  DATA lv_len  TYPE i.

  lv_len = strlen( p_dir ) - 1.
  IF lv_len >= 0.
    lv_last = p_dir+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE p_dir '\' INTO p_dir.
    ENDIF.
  ENDIF.

ENDFORM.

FORM f_backup_reports.

  DATA:
    lt_trdir    TYPE STANDARD TABLE OF trdir-name,
    lv_program  TYPE trdir-name,
    lv_filename TYPE string,
    lv_exported TYPE i,
    lv_skipped  TYPE i.

  SELECT name
    INTO TABLE lt_trdir
    FROM trdir
   WHERE name EQ 'ZHR_SENIOR_EXP_1000'
      OR name EQ 'ZHR_SENIOR_EXP_1001'
      OR name EQ 'ZHR_SENIOR_EXP_1002'
      OR name EQ 'ZHR_SENIOR_EXP_1003'
      OR name EQ 'ZHR_SENIOR_EXP_1004'
      OR name EQ 'ZHR_SENIOR_EXP_1005'
      OR name EQ 'ZHR_SENIOR_EXP_1006'
      OR name EQ 'ZHR_SENIOR_EXP_1007'
      OR name EQ 'ZHR_SENIOR_EXP_1008'
      OR name EQ 'ZHR_SENIOR_EXP_1009'
      OR name EQ 'ZHR_SENIOR_EXP_1010'
      OR name EQ 'ZHR_SENIOR_EXP_1011'
      OR name EQ 'ZHR_SENIOR_EXP_1012'
      OR name EQ 'ZHR_SENIOR_EXP_1013'
      OR name EQ 'ZHR_SENIOR_EXP_1014'
      OR name EQ 'ZHR_SENIOR_EXP_1015'
      OR name EQ 'ZHR_SENIOR_EXP_1016'
      OR name EQ 'ZHR_SENIOR_EXP_1017'
      OR name EQ 'ZHR_SENIOR_EXP_1018'
      OR name EQ 'ZHR_SENIOR_EXP_1019'
      OR name EQ 'ZHR_SENIOR_EXP_1020'
      OR name EQ 'ZHR_SENIOR_EXP_1021'
      OR name EQ 'ZHR_SENIOR_EXP_1022'
      OR name EQ 'ZHR_SENIOR_EXP_1023'
      OR name EQ 'ZHR_SENIOR_EXP_1025'
      OR name EQ 'ZHR_SENIOR_EXP_1026'
      OR name EQ 'ZHR_SENIOR_EXP_1027'
      OR name EQ 'ZHR_SENIOR_EXP_1028'
      OR name EQ 'ZHR_SENIOR_EXP_1030'
      OR name EQ 'ZHR_SENIOR_EXP_1031'
      OR name EQ 'ZHR_SENIOR_EXP_1032'
      OR name EQ 'ZHR_SENIOR_EXP_1033'
      OR name EQ 'ZHR_SENIOR_EXP_1034'
      OR name EQ 'ZHR_SENIOR_EXP_1035'
      OR name EQ 'ZHR_SENIOR_EXP_1036'
      OR name EQ 'ZHR_SENIOR_EXP_1037'
      OR name EQ 'ZHR_SENIOR_EXP_1038'
      OR name EQ 'ZHR_SENIOR_EXP_1039'
      OR name EQ 'ZHR_SENIOR_EXP_1040'
      OR name EQ 'ZHR_SENIOR_EXP_1041'
      OR name EQ 'ZHR_SENIOR_EXP_1042'
      OR name EQ 'ZHR_SENIOR_EXP_1050'
      OR name EQ 'ZHR_SENIOR_EXP_1051'
      OR name EQ 'ZHR_SENIOR_EXP_1052'
      OR name EQ 'ZHR_SENIOR_EXP_1053'
      OR name EQ 'ZHR_SENIOR_EXP_1054'
      OR name EQ 'ZHR_SENIOR_EXP_1055'
   ORDER BY PRIMARY KEY.

  IF sy-subrc <> 0 OR lt_trdir IS INITIAL.
    MESSAGE 'Nenhum programa ZHR_SENIOR_EXP_* encontrado.' TYPE 'E'.
  ENDIF.

  LOOP AT lt_trdir INTO lv_program.
    PERFORM f_backup_one USING lv_program CHANGING lv_exported lv_skipped.
  ENDLOOP.

  WRITE: / 'Diretorio:', p_dir.
  WRITE: / 'Programas exportados:', lv_exported.
  WRITE: / 'Programas ignorados:', lv_skipped.

ENDFORM.

FORM f_backup_one USING    pv_program  TYPE trdir-name
                  CHANGING pv_exported TYPE i
                           pv_skipped  TYPE i.

  DATA:
    lt_source   TYPE STANDARD TABLE OF text255,
    lv_filename TYPE string.

  READ REPORT pv_program INTO lt_source.
  IF sy-subrc <> 0 OR lt_source IS INITIAL.
    ADD 1 TO pv_skipped.
    WRITE: / 'Ignorado:', pv_program.
    RETURN.
  ENDIF.

  lv_filename = pv_program.
  TRANSLATE lv_filename TO LOWER CASE.
  CONCATENATE p_dir lv_filename '.prog.abap' INTO lv_filename.

  IF p_test = 'X'.
    ADD 1 TO pv_exported.
    WRITE: / 'Teste:', pv_program, '->', lv_filename.
    RETURN.
  ENDIF.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_filename
      filetype = 'ASC'
    TABLES
      data_tab = lt_source
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    ADD 1 TO pv_skipped.
    WRITE: / 'Erro ao exportar:', pv_program.
    RETURN.
  ENDIF.

  ADD 1 TO pv_exported.
  WRITE: / 'Exportado:', pv_program.

ENDFORM.