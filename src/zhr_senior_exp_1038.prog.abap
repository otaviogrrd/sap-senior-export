REPORT zhr_senior_exp_1038.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_term,
         pernr  TYPE pernr_d,
         datdem TYPE begda,
         massn  TYPE massn,
         massg  TYPE massg,
         bukrs  TYPE bukrs,
         persg  TYPE persg,
       END OF ty_term.

TYPES: BEGIN OF ty_pay,
         pernr  TYPE pernr_d,
         datdem TYPE begda,
         massn  TYPE massn,
         massg  TYPE massg,
         bukrs  TYPE bukrs,
         persg  TYPE persg,
         paydt  TYPE pc261-paydt,
         fpbeg  TYPE pc261-fpbeg,
         fpend  TYPE pc261-fpend,
         seqnr  TYPE pc261-seqnr,
         rank   TYPE i,
       END OF ty_pay.

TYPES ty_t_term TYPE STANDARD TABLE OF ty_term WITH DEFAULT KEY.
TYPES ty_t_pay  TYPE STANDARD TABLE OF ty_pay WITH DEFAULT KEY.

DATA: gt_term TYPE STANDARD TABLE OF ty_term,
      gt_pay  TYPE STANDARD TABLE OF ty_pay.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_export.

FORM f_export.

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string,
        gt_file     TYPE STANDARD TABLE OF string.

  gv_filename = sy-datum && '_SENIOR_1038.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATPAG;TABEVE;CODEVE;REFEVE;VALEVE'.

  APPEND gv_header TO gt_file.

  SELECT
    p0~pernr,
    p0~begda AS datdem,
    p0~massn,
    p0~massg,
    p1~bukrs,
    p1~persg
    INTO TABLE @gt_term
    FROM pa0000 AS p0
    LEFT JOIN pa0001 AS p1
      ON p1~pernr = p0~pernr
     AND p1~begda <= p0~begda
     AND p1~endda >= p0~begda
   WHERE p0~stat2 = '0'
     AND p0~begda <= @sy-datum.

  IF gt_term IS INITIAL.
    PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.
    WRITE: / 'Layout 1038 gerado:', gv_filename.
    RETURN.
  ENDIF.

  SORT gt_term BY pernr datdem massn massg.
  DELETE ADJACENT DUPLICATES FROM gt_term COMPARING pernr datdem massn massg.

  PERFORM f_collect_payments.

  LOOP AT gt_pay ASSIGNING FIELD-SYMBOL(<fs_pay>).

    DATA: lv_numemp TYPE string,
          lv_tipcol TYPE string,
          lv_numcad TYPE string,
          lv_datpag TYPE string,
          lv_tabeve TYPE string,
          lv_codeve TYPE string,
          lv_refeve TYPE string,
          lv_valeve TYPE string.

    DATA lt_rt TYPE STANDARD TABLE OF pc207.

    PERFORM f_read_payroll_result
      USING <fs_pay>-pernr <fs_pay>-seqnr
      CHANGING lt_rt.

    IF lt_rt IS INITIAL.
      CONTINUE.
    ENDIF.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_pay>-persg
      CHANGING lv_tipcol.

    lv_numemp = <fs_pay>-bukrs.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_pay>-bukrs
      CHANGING lv_numemp.
    lv_numcad = |{ <fs_pay>-pernr ALPHA = OUT }|.
    lv_tabeve = '1'.
    PERFORM f_format_date USING <fs_pay>-paydt CHANGING lv_datpag.

    LOOP AT lt_rt ASSIGNING FIELD-SYMBOL(<fs_rt>).
      IF <fs_rt>-betrg IS INITIAL
         AND <fs_rt>-anzhl IS INITIAL.
        CONTINUE.
      ENDIF.

      PERFORM f_wagetype_code
        USING <fs_rt>-lgart
        CHANGING lv_codeve.

      IF lv_codeve IS INITIAL.
        CONTINUE.
      ENDIF.

      PERFORM f_format_amount USING <fs_rt>-anzhl CHANGING lv_refeve.
      PERFORM f_format_amount USING <fs_rt>-betrg CHANGING lv_valeve.

      PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
      PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
      PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
      PERFORM f_fit_field USING lv_datpag 10 CHANGING lv_datpag.
      PERFORM f_fit_field USING lv_tabeve 3 CHANGING lv_tabeve.
      PERFORM f_fit_field USING lv_codeve 4 CHANGING lv_codeve.
      PERFORM f_fit_field USING lv_refeve 12 CHANGING lv_refeve.
      PERFORM f_fit_field USING lv_valeve 12 CHANGING lv_valeve.

      CONCATENATE
        lv_numemp
        lv_tipcol
        lv_numcad
        lv_datpag
        lv_tabeve
        lv_codeve
        lv_refeve
        lv_valeve
        INTO gv_line
        SEPARATED BY ';'.

      APPEND gv_line TO gt_file.
    ENDLOOP.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1038 gerado:', gv_filename.

ENDFORM.

FORM f_collect_payments
  .

  DATA: lt_term  TYPE ty_t_term,
        lt_rgdir TYPE STANDARD TABLE OF pc261,
        ls_pay   TYPE ty_pay,
        lv_pernr TYPE pernr_d,
        lv_keydt TYPE datum.

  FIELD-SYMBOLS: <fs_term>  TYPE ty_term,
                 <fs_rgdir> TYPE pc261,
                 <fs_pay>   TYPE ty_pay.

  lt_term = gt_term.
  SORT lt_term BY pernr datdem.

  LOOP AT lt_term ASSIGNING <fs_term>.
    AT NEW pernr.
      FREE lt_rgdir[].
      lv_pernr = <fs_term>-pernr.

      DATA(lo_payroll) = NEW cl_hr_br_read_payroll( iv_pernr = lv_pernr ).
      IF lo_payroll IS BOUND.
        lo_payroll->get_rgdir(
          EXPORTING
            iv_begda       = '19000101'
            iv_endda       = '99991231'
            iv_srtza       = 'A'
            iv_reorg_rgdir = abap_true
          IMPORTING
            et_rgdir       = lt_rgdir ).
      ENDIF.
    ENDAT.

    LOOP AT lt_rgdir ASSIGNING <fs_rgdir>
      WHERE void  = space
        AND srtza = 'A'.

      IF <fs_rgdir>-ocrsn <> 'RESC'
         AND <fs_rgdir>-occat <> '08'.
        CONTINUE.
      ENDIF.

      lv_keydt = <fs_rgdir>-paydt.
      IF lv_keydt IS INITIAL.
        lv_keydt = <fs_rgdir>-fpend.
      ENDIF.
      IF lv_keydt IS INITIAL.
        lv_keydt = <fs_rgdir>-fpbeg.
      ENDIF.

      IF lv_keydt < <fs_term>-datdem.
        CONTINUE.
      ENDIF.

      CLEAR ls_pay.
      ls_pay-pernr  = <fs_term>-pernr.
      ls_pay-datdem = <fs_term>-datdem.
      ls_pay-massn  = <fs_term>-massn.
      ls_pay-massg  = <fs_term>-massg.
      ls_pay-bukrs  = <fs_term>-bukrs.
      ls_pay-persg  = <fs_term>-persg.
      ls_pay-paydt  = <fs_rgdir>-paydt.
      ls_pay-fpbeg  = <fs_rgdir>-fpbeg.
      ls_pay-fpend  = <fs_rgdir>-fpend.
      ls_pay-seqnr  = <fs_rgdir>-seqnr.
      APPEND ls_pay TO gt_pay.
    ENDLOOP.
  ENDLOOP.

  SORT gt_pay BY pernr datdem paydt seqnr DESCENDING.
  DELETE ADJACENT DUPLICATES FROM gt_pay COMPARING pernr datdem paydt.
  SORT gt_pay BY pernr datdem paydt seqnr.

  DATA: lv_last_pernr TYPE pernr_d,
        lv_last_datdem TYPE begda,
        lv_rank TYPE i.

  CLEAR: lv_last_pernr, lv_last_datdem, lv_rank.

  LOOP AT gt_pay ASSIGNING <fs_pay>.
    IF <fs_pay>-pernr <> lv_last_pernr
       OR <fs_pay>-datdem <> lv_last_datdem.
      lv_last_pernr = <fs_pay>-pernr.
      lv_last_datdem = <fs_pay>-datdem.
      lv_rank = 0.
    ENDIF.
    ADD 1 TO lv_rank.
    <fs_pay>-rank = lv_rank.
  ENDLOOP.

ENDFORM.

FORM f_read_payroll_result
  USING    pv_pernr TYPE pernr_d
           pv_seqnr TYPE pc261-seqnr
  CHANGING pt_rt    TYPE STANDARD TABLE.

  DATA ls_rgdir TYPE pc261.

  CLEAR pt_rt[].

  DATA(lo_payroll) = NEW cl_hr_br_read_payroll( iv_pernr = pv_pernr ).
  IF lo_payroll IS NOT BOUND.
    RETURN.
  ENDIF.

  SELECT SINGLE *
    INTO @DATA(ls_hrpy_rgdir)
    FROM hrpy_rgdir
   WHERE pernr = @pv_pernr
     AND seqnr = @pv_seqnr.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  MOVE-CORRESPONDING ls_hrpy_rgdir TO ls_rgdir.

  lo_payroll->get_pay_result(
    EXPORTING
      is_rgdir        = ls_rgdir
    IMPORTING
      es_paybr_result = DATA(ls_result) ).

  pt_rt[] = ls_result-inter-rt[].

ENDFORM.

FORM f_wagetype_code
  USING    pv_lgart TYPE lgart
  CHANGING pv_code  TYPE string.

  DATA: lv_digits TYPE string,
        lv_off    TYPE i.

  pv_code = pv_lgart.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN pv_code WITH ''.

  lv_digits = pv_code.
  IF lv_digits IS INITIAL.
    CLEAR pv_code.
  ELSEIF strlen( lv_digits ) > 4.
    lv_off = strlen( lv_digits ) - 4.
    pv_code = lv_digits+lv_off(4).
  ELSE.
    pv_code = lv_digits.
  ENDIF.

ENDFORM.

FORM f_format_date
  USING    pv_date TYPE datum
  CHANGING pv_text TYPE string.

  CLEAR pv_text.

  IF pv_date IS INITIAL
     OR pv_date = '00000000'.
    RETURN.
  ENDIF.

  PERFORM f_conv_date IN PROGRAM zhr_export_senior
    USING pv_date
    CHANGING pv_text.

ENDFORM.

FORM f_format_amount
  USING    pv_value TYPE any
  CHANGING pv_text  TYPE string.

  DATA: lv_value TYPE p LENGTH 15 DECIMALS 2,
        lv_text  TYPE c LENGTH 40.

  CLEAR pv_text.
  CLEAR lv_text.
  lv_value = pv_value.

  WRITE lv_value TO lv_text DECIMALS 2 NO-GROUPING.
  CONDENSE lv_text NO-GAPS.
  REPLACE ALL OCCURRENCES OF '.' IN lv_text WITH ','.
  pv_text = lv_text.

ENDFORM.

FORM f_fit_field
  USING    pv_value  TYPE any
           pv_length TYPE i
  CHANGING pv_text   TYPE string.

  pv_text = |{ pv_value }|.
  REPLACE ALL OCCURRENCES OF ';' IN pv_text WITH ','.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN pv_text WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN pv_text WITH space.
  CONDENSE pv_text.

  IF pv_length > 0
     AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.
