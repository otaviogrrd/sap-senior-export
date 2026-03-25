REPORT zhr_export_senior_3.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

DATA:
  gt_programs TYPE STANDARD TABLE OF trdir-name WITH EMPTY KEY,
  gt_log      TYPE STANDARD TABLE OF text255 WITH EMPTY KEY,
  gv_total    TYPE i,
  gv_done     TYPE i.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_validate.
  PERFORM f_get_programs.
  PERFORM f_run_programs.
  PERFORM f_show_log.

FORM f_validate.

  IF p_locl IS INITIAL AND p_serv IS INITIAL.
    MESSAGE 'Informe o destino local ou no servidor.' TYPE 'E'.
  ENDIF.

ENDFORM.

FORM f_get_programs.

  CLEAR gt_programs.

  APPEND 'ZHR_SENIOR_EXP_1000' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1001' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1002' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1003' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1004' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1005' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1006' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1007' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1008' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1009' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1010' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1011' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1012' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1013' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1014' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1015' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1016' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1017' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1018' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1019' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1020' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1021' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1022' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1023' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1025' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1026' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1027' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1028' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1030' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1031' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1032' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1033' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1034' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1035' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1036' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1037' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1038' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1039' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1040' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1041' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1042' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1050' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1051' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1052' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1053' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1054' TO gt_programs.
  APPEND 'ZHR_SENIOR_EXP_1055' TO gt_programs.

  IF gt_programs IS INITIAL.
    MESSAGE 'Nenhum programa ZHR_SENIOR_EXP_* encontrado.' TYPE 'E'.
  ENDIF.

  gv_total = lines( gt_programs ).

ENDFORM.

FORM f_run_programs.

  DATA:
    lv_program TYPE trdir-name,
    lv_text    TYPE text255.

  LOOP AT gt_programs INTO lv_program.
    ADD 1 TO gv_done.

    CONCATENATE 'Executando' gv_done 'de' gv_total ':' lv_program
      INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.

    SUBMIT (lv_program)
      WITH p_locl = p_locl
      WITH p_serv = p_serv
      EXPORTING LIST TO MEMORY
      AND RETURN.

    CALL FUNCTION 'LIST_FREE_MEMORY'
      EXCEPTIONS
        not_found = 1
        OTHERS    = 2.

    CONCATENATE 'Concluido:' lv_program INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.
  ENDLOOP.

ENDFORM.

FORM f_show_log.

  DATA lv_text TYPE text255.

  WRITE: / 'Programas encontrados:', gv_total.
  WRITE: / 'Programas executados:', gv_done.

  IF p_locl IS NOT INITIAL.
    WRITE: / 'Destino local:', p_locl.
  ENDIF.

  IF p_serv IS NOT INITIAL.
    WRITE: / 'Destino servidor:', p_serv.
  ENDIF.

  ULINE.

  LOOP AT gt_log INTO lv_text.
    WRITE: / lv_text.
  ENDLOOP.

ENDFORM.
