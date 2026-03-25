REPORT zhr_export_senior_1.

PARAMETERS:
  p_test AS CHECKBOX.

DATA:
  gt_input TYPE STANDARD TABLE OF text255,
  gt_log   TYPE STANDARD TABLE OF text255.

START-OF-SELECTION.

  PERFORM f_read_pasted_content.
  PERFORM f_process_bundle.
  PERFORM f_show_log.

FORM f_read_pasted_content.

  DATA lv_title TYPE string.

  lv_title = 'Cole o bundle com os fontes'.

  CALL FUNCTION 'TERM_CONTROL_EDIT'
    EXPORTING
      titel          = lv_title
    TABLES
      textlines      = gt_input
    EXCEPTIONS
      user_cancelled = 1
      OTHERS         = 2.

  IF sy-subrc <> 0 OR gt_input IS INITIAL.
    MESSAGE 'Nenhum conteudo foi informado.' TYPE 'E'.
  ENDIF.

ENDFORM.

FORM f_process_bundle.

  DATA:
    lt_source   TYPE STANDARD TABLE OF text255,
    lv_line     TYPE text255,
    lv_marker   TYPE string,
    lv_program  TYPE progname,
    lv_filename TYPE string.

  LOOP AT gt_input INTO lv_line.
    lv_marker = lv_line.

    IF lv_marker CP '###FILE:*'.
      IF lv_program IS NOT INITIAL.
        PERFORM f_save_report USING lv_program lv_filename
                              CHANGING lt_source.
      ENDIF.

      CLEAR lv_program.
      CLEAR lv_filename.
      CLEAR lt_source[].

      lv_filename = lv_marker+8.
      CONDENSE lv_filename NO-GAPS.
      PERFORM f_filename_to_program USING lv_filename
                                    CHANGING lv_program.

      IF lv_program IS INITIAL.
        APPEND 'Arquivo ignorado por nome invalido.' TO gt_log.
      ENDIF.
      CONTINUE.
    ENDIF.

    IF lv_program IS INITIAL.
      CONTINUE.
    ENDIF.

    APPEND lv_line TO lt_source.
  ENDLOOP.

  IF lv_program IS NOT INITIAL.
    PERFORM f_save_report USING lv_program lv_filename
                          CHANGING lt_source.
  ENDIF.

ENDFORM.

FORM f_filename_to_program USING    pv_filename TYPE string
                           CHANGING pv_program  TYPE progname.

  pv_program = pv_filename.
  TRANSLATE pv_program TO UPPER CASE.

  REPLACE FIRST OCCURRENCE OF '.PROG.ABAP' IN pv_program WITH ''.
  REPLACE FIRST OCCURRENCE OF '.ABAP' IN pv_program WITH ''.

  IF pv_program NE 'ZHR_EXPORT_SENIOR'
     AND pv_program NP 'ZHR_SENIOR_EXP_*'.
    CLEAR pv_program.
  ENDIF.

ENDFORM.

FORM f_save_report USING    pv_program  TYPE progname
                            pv_filename TYPE string
                   CHANGING pt_source   TYPE STANDARD TABLE.

  DATA:
    lt_objects TYPE STANDARD TABLE OF dwinactiv,
    ls_object  TYPE dwinactiv,
    lv_text    TYPE text255.

  IF pt_source IS INITIAL.
    CONCATENATE 'Sem linhas para' pv_program INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.
    RETURN.
  ENDIF.

  IF p_test = 'X'.
    CONCATENATE 'Teste:' pv_program pv_filename INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.
    RETURN.
  ENDIF.

  INSERT REPORT pv_program FROM pt_source.
  IF sy-subrc <> 0.
    CONCATENATE 'Erro ao gravar:' pv_program INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.
    RETURN.
  ENDIF.

  CLEAR ls_object.
  ls_object-object   = 'PROG'.
  ls_object-obj_name = pv_program.
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
    CONCATENATE 'Gravado sem ativar:' pv_program INTO lv_text SEPARATED BY space.
    APPEND lv_text TO gt_log.
    RETURN.
  ENDIF.

  CONCATENATE 'Programa carregado e ativado:' pv_program INTO lv_text SEPARATED BY space.
  APPEND lv_text TO gt_log.

ENDFORM.

FORM f_show_log.

  DATA lv_line TYPE text255.

  LOOP AT gt_log INTO lv_line.
    WRITE: / lv_line.
  ENDLOOP.

  IF gt_log IS INITIAL.
    WRITE: / 'Nenhum programa foi processado.'.
  ENDIF.

  ULINE.
  WRITE: / 'Formato esperado:'.
  WRITE: / '###FILE: zhr_senior_exp_1000.prog.abap'.
  WRITE: / 'REPORT zhr_senior_exp_1000.'.

ENDFORM.
