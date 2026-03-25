REPORT zhr_export_table_sched.
TABLES dd02l.

PARAMETERS: p_hcm  AS CHECKBOX DEFAULT 'X',
            p_all  AS CHECKBOX DEFAULT space,
            p_test AS CHECKBOX DEFAULT 'X'.

SELECT-OPTIONS: s_tab FOR dd02l-tabname NO INTERVALS.

DATA: lt_tables   TYPE STANDARD TABLE OF dd02l-tabname WITH EMPTY KEY,
      lv_tabname  TYPE dd02l-tabname,
      lv_jobname  TYPE tbtcjob-jobname,
      lv_jobcount TYPE tbtcjob-jobcount,
      gv_created  TYPE i,
      gv_errors   TYPE i.

START-OF-SELECTION.

  PERFORM get_tables.
  PERFORM remove_unsupported_tables.
  PERFORM schedule_jobs.
  PERFORM show_summary.

*---------------------------------------------------------------------*
* Busca dinâmica das tabelas elegíveis
*---------------------------------------------------------------------*
FORM get_tables.

  IF p_all = 'X'.

    SELECT tabname
      FROM dd02l
      INTO TABLE @lt_tables
      WHERE as4local = 'A'
        AND tabclass = 'TRANSP'
        AND tabname NOT LIKE '/1%'
        AND tabname NOT LIKE 'M_%'
        AND tabname NOT LIKE 'R%'
        AND tabname NOT LIKE 'USR%'
        AND tabname NOT LIKE 'TEMSE%'
        AND tabname NOT LIKE 'TBTC%'.

  ELSEIF p_hcm = 'X'.

    " Faixas mais comuns de HCM / PY / OM / TM / customizing RH
    SELECT tabname
      FROM dd02l
      INTO TABLE @lt_tables
      WHERE as4local = 'A'
        AND tabclass = 'TRANSP'
        AND (
             tabname LIKE 'PA%'
          OR tabname LIKE 'PB%'
          OR tabname LIKE 'HRP%'
          OR tabname LIKE 'HRT%'
          OR tabname LIKE 'T5%'
          OR tabname LIKE 'T7%'
          OR tabname LIKE 'P5%'
          OR tabname LIKE 'P7%'
          OR tabname LIKE 'PLOGI%'
          OR tabname LIKE 'T77%'
          OR tabname LIKE 'T52%'
          OR tabname LIKE 'T51%'
          OR tabname LIKE 'T50%'
          OR tabname LIKE 'ZHR%'
          OR tabname LIKE 'YHR%'
            ).

  ELSE.

    " Caso o usuário informe manualmente no select-option
    IF s_tab[] IS INITIAL.
      MESSAGE 'Informe s_tab ou marque p_hcm/p_all.' TYPE 'E'.
    ENDIF.

    SELECT tabname
      FROM dd02l
      INTO TABLE @lt_tables
      WHERE as4local = 'A'
        AND tabclass = 'TRANSP'
        AND tabname IN @s_tab.

  ENDIF.

  IF s_tab[] IS NOT INITIAL.
    DELETE lt_tables WHERE table_line NOT IN s_tab.
  ENDIF.

  SORT lt_tables.
  DELETE ADJACENT DUPLICATES FROM lt_tables.

  IF lt_tables IS INITIAL.
    MESSAGE 'Nenhuma tabela elegível encontrada.' TYPE 'E'.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
* Remove tabelas que não fazem sentido para esse extrator simples
*---------------------------------------------------------------------*
FORM remove_unsupported_tables.

  DATA lt_remove TYPE STANDARD TABLE OF dd02l-tabname WITH EMPTY KEY.

  LOOP AT lt_tables INTO lv_tabname.

    " Evita objetos técnicos ou estruturas incomuns
    IF lv_tabname CP 'PCL*'
    OR lv_tabname CP 'PC2*'
    OR lv_tabname CP 'PSKEY'
    OR lv_tabname CP 'T77S0'
    OR lv_tabname CP 'T77UA'
    OR lv_tabname CP 'T77*AUTH*'.
      APPEND lv_tabname TO lt_remove.
      CONTINUE.
    ENDIF.

  ENDLOOP.

  LOOP AT lt_remove INTO lv_tabname.
    DELETE lt_tables WHERE table_line = lv_tabname.
  ENDLOOP.

  IF lt_tables IS INITIAL.
    MESSAGE 'Após filtros, não restaram tabelas suportadas.' TYPE 'E'.
  ENDIF.

ENDFORM.
*---------------------------------------------------------------------*
* Verifica se a tabela possui pelo menos 1 registro
*---------------------------------------------------------------------*
FORM check_table_has_data
  USING    pv_tabname   TYPE dd02l-tabname
  CHANGING pv_has_data  TYPE abap_bool.

  FIELD-SYMBOLS <fs_any> TYPE any.
  DATA lr_line TYPE REF TO data.

  CLEAR pv_has_data.

  CREATE DATA lr_line TYPE (pv_tabname).
  ASSIGN lr_line->* TO <fs_any>.

  SELECT SINGLE *
    FROM (pv_tabname)
    INTO <fs_any>.

  IF sy-subrc = 0.
    pv_has_data = abap_true.
  ENDIF.

ENDFORM.
*---------------------------------------------------------------------*
* Cria 1 job por tabela
*---------------------------------------------------------------------*
FORM schedule_jobs.

  DATA lv_has_data TYPE abap_bool.

  LOOP AT lt_tables INTO lv_tabname.

    CLEAR: lv_jobname, lv_jobcount, lv_has_data.

    PERFORM check_table_has_data USING lv_tabname CHANGING lv_has_data.

    IF lv_has_data IS INITIAL.
      " WRITE: / 'Tabela sem dados, job não criado:', lv_tabname.
      CONTINUE.
    ENDIF.

    lv_jobname = |ZEXP_{ lv_tabname }|.

    IF p_test = 'X'.
      WRITE: / 'TESTE - Job seria criado para tabela:', lv_tabname.
      CONTINUE.
    ENDIF.

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
      WRITE: / 'Erro no JOB_OPEN:', lv_tabname.
      CONTINUE.
    ENDIF.

    SUBMIT zhr_export_table_csv
      WITH p_tab  = lv_tabname
      WITH p_file = ''
      WITH p_date = sy-datum
      VIA JOB lv_jobname NUMBER lv_jobcount
      AND RETURN.

    IF sy-subrc <> 0.
      ADD 1 TO gv_errors.
      WRITE: / 'Erro no SUBMIT:', lv_tabname.

      CALL FUNCTION 'JOB_CLOSE'
        EXPORTING
          jobcount  = lv_jobcount
          jobname   = lv_jobname
          strtimmed = abap_false
        EXCEPTIONS
          OTHERS    = 1.

      CONTINUE.
    ENDIF.

    CALL FUNCTION 'JOB_CLOSE'
      EXPORTING
        jobcount             = lv_jobcount
        jobname              = lv_jobname
        strtimmed            = abap_true
      EXCEPTIONS
        cant_start_immediate = 1
        invalid_startdate    = 2
        jobname_missing      = 3
        job_close_failed     = 4
        job_nosteps          = 5
        job_notex            = 6
        lock_failed          = 7
        OTHERS               = 8.

    IF sy-subrc = 0.
      ADD 1 TO gv_created.
      WRITE: / 'Job criado:', lv_jobname, 'Tabela:', lv_tabname.
    ELSE.
      ADD 1 TO gv_errors.
      WRITE: / 'Erro no JOB_CLOSE:', lv_tabname.
    ENDIF.

  ENDLOOP.

ENDFORM.

*---------------------------------------------------------------------*
* Resumo final
*---------------------------------------------------------------------*
FORM show_summary.

  ULINE.
  WRITE: / 'Total de tabelas elegíveis:', lines( lt_tables ).
  WRITE: / 'Jobs criados:', gv_created.
  WRITE: / 'Erros:', gv_errors.

  IF p_test = 'X'.
    WRITE: / 'Modo teste ativo: nenhum job foi criado.'.
  ENDIF.

ENDFORM.
