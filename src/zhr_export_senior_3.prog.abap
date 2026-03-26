REPORT zhr_export_senior_3.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE,
            p_prog TYPE sy-repid NO-DISPLAY.

DATA:
  gt_programs TYPE STANDARD TABLE OF trdir-name WITH EMPTY KEY,
  gt_log      TYPE STANDARD TABLE OF text255 WITH EMPTY KEY,
  gv_total    TYPE i,
  gv_done     TYPE i,
  gv_created  TYPE i,
  gv_errors   TYPE i.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  IF p_prog IS NOT INITIAL.
    PERFORM f_run_single_program.
    RETURN.
  ENDIF.

  PERFORM f_validate.
  PERFORM f_get_programs.
  PERFORM f_run_programs.
  PERFORM f_show_log.

FORM f_validate.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o diretorio no servidor para execucao em background.' TYPE 'E'.
  ENDIF.

  IF p_locl IS NOT INITIAL.
    MESSAGE 'Execucao em background suporta apenas p_serv.' TYPE 'E'.
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
    lv_program    TYPE trdir-name,
    lv_text       TYPE text255,
    lv_jobname    TYPE tbtcjob-jobname,
    lv_jobcount   TYPE tbtcjob-jobcount,
    lv_done_text  TYPE char10,
    lv_total_text TYPE char10.

  LOOP AT gt_programs INTO lv_program.
    ADD 1 TO gv_done.

    WRITE gv_done TO lv_done_text LEFT-JUSTIFIED.
    WRITE gv_total TO lv_total_text LEFT-JUSTIFIED.

    CONCATENATE 'Agendando' lv_done_text 'de' lv_total_text ':' lv_program
      INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.

    lv_jobname = lv_program.

    CALL FUNCTION 'JOB_OPEN'
      EXPORTING
        jobname          = lv_jobname
      IMPORTING
        jobcount         = lv_jobcount
      EXCEPTIONS
        cant_create_job  = 1
        invalid_job_data = 2
        jobname_missing  = 3
        OTHERS           = 4.

    IF sy-subrc <> 0.
      ADD 1 TO gv_errors.
      CONCATENATE 'Erro no JOB_OPEN:' lv_program INTO lv_text SEPARATED BY space.
      APPEND lv_text TO gt_log.
      CONTINUE.
    ENDIF.

    SUBMIT zhr_export_senior_3
      WITH p_serv = p_serv
      WITH p_prog = lv_program
      VIA JOB lv_jobname NUMBER lv_jobcount
      AND RETURN.

    IF sy-subrc <> 0.
      ADD 1 TO gv_errors.
      CONCATENATE 'Erro no SUBMIT:' lv_program INTO lv_text SEPARATED BY space.
      APPEND lv_text TO gt_log.

      CALL FUNCTION 'JOB_CLOSE'
        EXPORTING
          jobcount  = lv_jobcount
          jobname   = lv_jobname
          strtimmed = space
        EXCEPTIONS
          OTHERS    = 1.

      CONTINUE.
    ENDIF.

    CALL FUNCTION 'JOB_CLOSE'
      EXPORTING
        jobcount             = lv_jobcount
        jobname              = lv_jobname
        strtimmed            = 'X'
      EXCEPTIONS
        cant_start_immediate = 1
        invalid_startdate    = 2
        jobname_missing      = 3
        job_close_failed     = 4
        job_nosteps          = 5
        job_notex            = 6
        lock_failed          = 7
        OTHERS               = 8.

    IF sy-subrc <> 0.
      ADD 1 TO gv_errors.
      CONCATENATE 'Erro no JOB_CLOSE:' lv_program INTO lv_text SEPARATED BY space.
      APPEND lv_text TO gt_log.
      CONTINUE.
    ENDIF.

    ADD 1 TO gv_created.
    CONCATENATE 'Job criado:' lv_jobname lv_jobcount INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.
  ENDLOOP.

ENDFORM.

FORM f_run_single_program.

  IF p_prog IS INITIAL.
    MESSAGE 'Programa alvo nao informado.' TYPE 'E'.
  ENDIF.

  SUBMIT (p_prog)
    WITH p_serv = p_serv
    AND RETURN.

ENDFORM.

FORM f_show_log.

  DATA lv_text TYPE text255.

  WRITE: / 'Programas na lista:', gv_total.
  WRITE: / 'Jobs criados:', gv_created.
  WRITE: / 'Erros no agendamento:', gv_errors.
  IF p_serv IS NOT INITIAL.
    WRITE: / 'Destino servidor:', p_serv.
  ENDIF.

  ULINE.

  LOOP AT gt_log INTO lv_text.
    WRITE: / lv_text.
  ENDLOOP.

ENDFORM.
