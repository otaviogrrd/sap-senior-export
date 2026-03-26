REPORT zhr_senior_exp_1036.

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

TYPES: BEGIN OF ty_0008,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
         bet01 TYPE pa0008-bet01,
       END OF ty_0008.

TYPES: BEGIN OF ty_0016,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
         ctedt TYPE pa0016-ctedt,
       END OF ty_0016.

TYPES: BEGIN OF ty_reason,
         massn TYPE massn,
         massg TYPE massg,
         mgtxt TYPE t530t-mgtxt,
       END OF ty_reason.

TYPES ty_t_term   TYPE STANDARD TABLE OF ty_term WITH DEFAULT KEY.
TYPES ty_t_pay    TYPE STANDARD TABLE OF ty_pay WITH DEFAULT KEY.
TYPES ty_t_0008   TYPE STANDARD TABLE OF ty_0008 WITH DEFAULT KEY.
TYPES ty_t_0016   TYPE STANDARD TABLE OF ty_0016 WITH DEFAULT KEY.
TYPES ty_t_reason TYPE STANDARD TABLE OF ty_reason WITH DEFAULT KEY.
TYPES ty_t_rt     TYPE STANDARD TABLE OF pc207 WITH DEFAULT KEY.

DATA: gt_term   TYPE STANDARD TABLE OF ty_term,
      gt_pay    TYPE STANDARD TABLE OF ty_pay,
      gt_0008   TYPE STANDARD TABLE OF ty_0008,
      gt_0016   TYPE STANDARD TABLE OF ty_0016,
      gt_reason TYPE STANDARD TABLE OF ty_reason.

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

  gv_filename = sy-datum && '_SENIOR_1036.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATDEM;CAUDEM;DATAVI;DATPAG;'
  && 'QTDIND;QTDREA;QTDSSL;QTDFCA;SALFAV;SLDFGT;COMRES;'
  && 'REPVAG;SALBAS;AVIPRE;JORSEM;SABCOM;QTDIAC;QTDRAC;'
  && 'TERQUI;ATEOBI;PROTRA'.

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
    WRITE: / 'Layout 1036 gerado:', gv_filename.
    RETURN.
  ENDIF.

  SORT gt_term BY pernr datdem massn massg.
  DELETE ADJACENT DUPLICATES FROM gt_term COMPARING pernr datdem massn massg.

  SELECT
    pernr,
    begda,
    endda,
    bet01
    INTO TABLE @gt_0008
    FROM pa0008
    FOR ALL ENTRIES IN @gt_term
   WHERE pernr = @gt_term-pernr.

  SELECT
    pernr,
    begda,
    endda,
    ctedt
    INTO TABLE @gt_0016
    FROM pa0016
    FOR ALL ENTRIES IN @gt_term
   WHERE pernr = @gt_term-pernr.

  SELECT
    massn,
    massg,
    mgtxt
    INTO TABLE @gt_reason
    FROM t530t
    FOR ALL ENTRIES IN @gt_term
   WHERE sprsl = @sy-langu
     AND massn = @gt_term-massn
     AND massg = @gt_term-massg.

  SORT gt_0008 BY pernr begda DESCENDING.
  SORT gt_0016 BY pernr begda DESCENDING.
  SORT gt_reason BY massn massg.

  PERFORM f_collect_payments.

  IF gt_pay IS INITIAL.
    PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.
    WRITE: / 'Layout 1036 gerado:', gv_filename.
    RETURN.
  ENDIF.

  LOOP AT gt_pay ASSIGNING FIELD-SYMBOL(<fs_pay>) WHERE rank = 1.

    DATA: lv_numemp TYPE string,
          lv_tipcol TYPE string,
          lv_numcad TYPE string,
          lv_datdem TYPE string,
          lv_caudem TYPE string,
          lv_datavi TYPE string,
          lv_datpag TYPE string,
          lv_qtdind TYPE string,
          lv_qtdrea TYPE string,
          lv_qtdssl TYPE string,
          lv_qtdfca TYPE string,
          lv_salfav TYPE string,
          lv_sldfgt TYPE string,
          lv_comres TYPE string,
          lv_repvag TYPE string,
          lv_salbas TYPE string,
          lv_avipre TYPE string,
          lv_jorsem TYPE string,
          lv_sabcom TYPE string,
          lv_qtdiac TYPE string,
          lv_qtdrac TYPE string,
          lv_terqui TYPE string,
          lv_ateobi TYPE string,
          lv_protra TYPE string.

    DATA: lv_qtdind_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdrea_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdssl_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdfca_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdiac_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdrac_num TYPE p LENGTH 8 DECIMALS 2,
          lv_salbas_num TYPE p LENGTH 11 DECIMALS 2,
          lv_salfav_num TYPE p LENGTH 11 DECIMALS 2,
          lv_sldfgt_num TYPE p LENGTH 11 DECIMALS 2.

    DATA: lt_rt TYPE STANDARD TABLE OF pc207,
          lv_reason_text TYPE string,
          lv_notice_date TYPE datum,
          lv_contract_end TYPE datum.

    PERFORM f_read_payroll_result
      USING <fs_pay>-pernr <fs_pay>-seqnr
      CHANGING lt_rt.

    PERFORM f_collect_rt_values
      TABLES lt_rt
      USING <fs_pay>-datdem
      CHANGING lv_qtdind_num
               lv_qtdrea_num
               lv_qtdssl_num
               lv_qtdfca_num
               lv_qtdiac_num
               lv_qtdrac_num
               lv_sldfgt_num.

    PERFORM f_get_salary_base
      USING <fs_pay>-pernr <fs_pay>-datdem
      CHANGING lv_salbas_num.

    lv_salfav_num = lv_salbas_num.

    PERFORM f_get_contract_end
      USING <fs_pay>-pernr <fs_pay>-datdem
      CHANGING lv_contract_end.

    IF lv_contract_end IS NOT INITIAL
       AND lv_contract_end > <fs_pay>-datdem
       AND lv_qtdfca_num IS INITIAL.
      lv_qtdfca_num = lv_contract_end - <fs_pay>-datdem.
    ENDIF.

    PERFORM f_get_reason_text
      USING <fs_pay>-massn <fs_pay>-massg
      CHANGING lv_reason_text.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_pay>-persg
      CHANGING lv_tipcol.

    PERFORM f_format_date USING <fs_pay>-datdem CHANGING lv_datdem.
    PERFORM f_format_date USING <fs_pay>-paydt CHANGING lv_datpag.

    IF lv_qtdind_num IS NOT INITIAL OR lv_qtdrea_num IS NOT INITIAL.
      lv_notice_date = <fs_pay>-datdem.
      lv_avipre = '2'.
    ELSE.
      lv_notice_date = <fs_pay>-datdem - 30.
      lv_avipre = '1'.
    ENDIF.

    PERFORM f_format_date USING lv_notice_date CHANGING lv_datavi.

    IF lv_qtdssl_num IS INITIAL AND <fs_pay>-datdem IS NOT INITIAL.
      lv_qtdssl_num = <fs_pay>-datdem+6(2).
    ENDIF.

    IF lv_reason_text CS 'OBIT'
       OR lv_reason_text CS 'FALEC'.
      lv_ateobi = 'ATESTADO OBITO'.
    ENDIF.

    lv_repvag = 'N'.
    lv_jorsem = '1'.
    lv_sabcom = '1'.
    lv_terqui = '1'.

    PERFORM f_reason_code
      USING <fs_pay>-massn <fs_pay>-massg
      CHANGING lv_caudem.

    lv_numemp = <fs_pay>-bukrs.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_pay>-bukrs
      CHANGING lv_numemp.
    lv_numcad = |{ <fs_pay>-pernr ALPHA = OUT }|.

    PERFORM f_format_amount USING lv_qtdind_num CHANGING lv_qtdind.
    PERFORM f_format_amount USING lv_qtdrea_num CHANGING lv_qtdrea.
    PERFORM f_format_amount USING lv_qtdssl_num CHANGING lv_qtdssl.
    PERFORM f_format_amount USING lv_qtdfca_num CHANGING lv_qtdfca.
    PERFORM f_format_amount USING lv_qtdiac_num CHANGING lv_qtdiac.
    PERFORM f_format_amount USING lv_qtdrac_num CHANGING lv_qtdrac.
    PERFORM f_format_amount USING lv_salbas_num CHANGING lv_salbas.
    PERFORM f_format_amount USING lv_salfav_num CHANGING lv_salfav.
    PERFORM f_format_amount USING lv_sldfgt_num CHANGING lv_sldfgt.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_caudem 2 CHANGING lv_caudem.
    PERFORM f_fit_field USING lv_datavi 10 CHANGING lv_datavi.
    PERFORM f_fit_field USING lv_datpag 10 CHANGING lv_datpag.
    PERFORM f_fit_field USING lv_qtdind 10 CHANGING lv_qtdind.
    PERFORM f_fit_field USING lv_qtdrea 10 CHANGING lv_qtdrea.
    PERFORM f_fit_field USING lv_qtdssl 10 CHANGING lv_qtdssl.
    PERFORM f_fit_field USING lv_qtdfca 10 CHANGING lv_qtdfca.
    PERFORM f_fit_field USING lv_salfav 12 CHANGING lv_salfav.
    PERFORM f_fit_field USING lv_sldfgt 12 CHANGING lv_sldfgt.
    PERFORM f_fit_field USING lv_reason_text 50 CHANGING lv_comres.
    PERFORM f_fit_field USING lv_repvag 1 CHANGING lv_repvag.
    PERFORM f_fit_field USING lv_salbas 12 CHANGING lv_salbas.
    PERFORM f_fit_field USING lv_avipre 1 CHANGING lv_avipre.
    PERFORM f_fit_field USING lv_jorsem 1 CHANGING lv_jorsem.
    PERFORM f_fit_field USING lv_sabcom 1 CHANGING lv_sabcom.
    PERFORM f_fit_field USING lv_qtdiac 10 CHANGING lv_qtdiac.
    PERFORM f_fit_field USING lv_qtdrac 10 CHANGING lv_qtdrac.
    PERFORM f_fit_field USING lv_terqui 1 CHANGING lv_terqui.
    PERFORM f_fit_field USING lv_ateobi 30 CHANGING lv_ateobi.
    PERFORM f_fit_field USING lv_protra 20 CHANGING lv_protra.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_datdem
      lv_caudem
      lv_datavi
      lv_datpag
      lv_qtdind
      lv_qtdrea
      lv_qtdssl
      lv_qtdfca
      lv_salfav
      lv_sldfgt
      lv_comres
      lv_repvag
      lv_salbas
      lv_avipre
      lv_jorsem
      lv_sabcom
      lv_qtdiac
      lv_qtdrac
      lv_terqui
      lv_ateobi
      lv_protra
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1036 gerado:', gv_filename.

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
      CLEAR lt_rgdir.
      lv_pernr = <fs_term>-pernr.

      CALL FUNCTION 'CU_READ_RGDIR'
        EXPORTING
          persnr          = lv_pernr
        TABLES
          in_rgdir        = lt_rgdir
        EXCEPTIONS
          no_record_found = 1
          OTHERS          = 2.
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

  DATA ls_payroll_result TYPE pay99_result.

  FIELD-SYMBOLS <lt_rt> TYPE STANDARD TABLE.

  CLEAR pt_rt[].

  CALL FUNCTION 'PYXX_READ_PAYROLL_RESULT'
    EXPORTING
      clusterid                 = 'RX'
      employeenumber            = pv_pernr
      sequencenumber            = pv_seqnr
      read_only_international   = 'X'
    CHANGING
      payroll_result            = ls_payroll_result
    EXCEPTIONS
      illegal_isocode_or_clusterid = 1
      error_generating_import      = 2
      import_mismatch_error        = 3
      subpool_dir_full             = 4
      no_read_authority            = 5
      no_record_found              = 6
      versions_do_not_match        = 7
      error_reading_archive        = 8
      error_reading_relid          = 9
      OTHERS                       = 10.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  ASSIGN ls_payroll_result-inter-rt[] TO <lt_rt>.
  IF <lt_rt> IS ASSIGNED.
    pt_rt[] = <lt_rt>[].
  ENDIF.

ENDFORM.

FORM f_collect_rt_values
  TABLES   pt_rt STRUCTURE pc207
  USING    pv_datdem TYPE datum
  CHANGING pv_qtdind TYPE p
           pv_qtdrea TYPE p
           pv_qtdssl TYPE p
           pv_qtdfca TYPE p
           pv_qtdiac TYPE p
           pv_qtdrac TYPE p
           pv_sldfgt TYPE p.

  CLEAR:
    pv_qtdind,
    pv_qtdrea,
    pv_qtdssl,
    pv_qtdfca,
    pv_qtdiac,
    pv_qtdrac,
    pv_sldfgt.

  LOOP AT pt_rt ASSIGNING FIELD-SYMBOL(<fs_rt>).
    CASE <fs_rt>-lgart.
      WHEN '/370'.
        pv_qtdind = pv_qtdind + <fs_rt>-anzhl.
      WHEN '/374'.
        pv_qtdrea = pv_qtdrea + <fs_rt>-anzhl.
      WHEN '/371'.
        pv_qtdfca = pv_qtdfca + <fs_rt>-anzhl.
    ENDCASE.
  ENDLOOP.

  IF pv_qtdssl IS INITIAL
     AND pv_datdem IS NOT INITIAL.
    pv_qtdssl = pv_datdem+6(2).
  ENDIF.

ENDFORM.

FORM f_get_salary_base
  USING    pv_pernr TYPE pernr_d
           pv_keydt TYPE datum
  CHANGING pv_salbas TYPE p.

  CLEAR pv_salbas.

  LOOP AT gt_0008 ASSIGNING FIELD-SYMBOL(<fs_0008>)
    WHERE pernr = pv_pernr.
    IF <fs_0008>-begda <= pv_keydt
       AND <fs_0008>-endda >= pv_keydt.
      pv_salbas = <fs_0008>-bet01.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_get_contract_end
  USING    pv_pernr TYPE pernr_d
           pv_keydt TYPE datum
  CHANGING pv_ctedt TYPE datum.

  CLEAR pv_ctedt.

  LOOP AT gt_0016 ASSIGNING FIELD-SYMBOL(<fs_0016>)
    WHERE pernr = pv_pernr.
    IF <fs_0016>-begda <= pv_keydt
       AND <fs_0016>-endda >= pv_keydt.
      pv_ctedt = <fs_0016>-ctedt.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_get_reason_text
  USING    pv_massn TYPE massn
           pv_massg TYPE massg
  CHANGING pv_text  TYPE string.

  CLEAR pv_text.

  READ TABLE gt_reason ASSIGNING FIELD-SYMBOL(<fs_reason>)
    WITH KEY massn = pv_massn
             massg = pv_massg
    BINARY SEARCH.
  IF sy-subrc = 0.
    pv_text = <fs_reason>-mgtxt.
  ENDIF.

ENDFORM.

FORM f_reason_code
  USING    pv_massn TYPE massn
           pv_massg TYPE massg
  CHANGING pv_code  TYPE string.

  DATA: lv_digits TYPE string,
        lv_off    TYPE i.

  CLEAR pv_code.

  PERFORM f_extract_digits USING pv_massg CHANGING lv_digits.
  IF lv_digits IS INITIAL.
    PERFORM f_extract_digits USING pv_massn CHANGING lv_digits.
  ENDIF.

  IF lv_digits IS INITIAL.
    pv_code = '99'.
  ELSEIF strlen( lv_digits ) > 2.
    lv_off = strlen( lv_digits ) - 2.
    pv_code = lv_digits+lv_off(2).
  ELSE.
    pv_code = lv_digits.
  ENDIF.

ENDFORM.

FORM f_extract_digits
  USING    pv_value  TYPE any
  CHANGING pv_digits TYPE string.

  pv_digits = |{ pv_value }|.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN pv_digits WITH ''.

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
