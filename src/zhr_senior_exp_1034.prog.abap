REPORT zhr_senior_exp_1034.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_quota,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
       END OF ty_quota.

TYPES: BEGIN OF ty_vac,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         awart TYPE pa2001-awart,
         abwtg TYPE pa2001-abwtg,
       END OF ty_vac.

TYPES: BEGIN OF ty_salary,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
         bet01 TYPE pa0008-bet01,
       END OF ty_salary.

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

  DATA: gt_quota  TYPE STANDARD TABLE OF ty_quota,
        gt_vac    TYPE STANDARD TABLE OF ty_vac,
        gt_salary TYPE STANDARD TABLE OF ty_salary.

  gv_filename = sy-datum && '_SENIOR_1034.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;INIPER;INIFER;TABEVE;CODEVE;'
  && 'REFEVE;VALEVE'.

  APPEND gv_header TO gt_file.

  SELECT pernr, begda, endda
    INTO TABLE @gt_quota
    FROM pa2006.

  SELECT
    p2001~pernr,
    p1~bukrs,
    p1~persg,
    p2001~begda,
    p2001~awart,
    p2001~abwtg
    INTO TABLE @gt_vac
    FROM pa2001 AS p2001
    INNER JOIN pa0001 AS p1
      ON p1~pernr = p2001~pernr
     AND p1~begda <= p2001~begda
     AND p1~endda >= p2001~begda
   WHERE p2001~awart IN ( '0100', '0120', '0130', '0150', '9100', '9120' ).

  IF gt_vac IS INITIAL.
    PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.
    WRITE: / 'Layout 1034 gerado:', gv_filename.
    RETURN.
  ENDIF.

  SELECT pernr, begda, endda, bet01
    INTO TABLE @gt_salary
    FROM pa0008
    FOR ALL ENTRIES IN @gt_vac
   WHERE pernr = @gt_vac-pernr.

  SORT gt_quota BY pernr begda DESCENDING endda DESCENDING.
  SORT gt_salary BY pernr begda DESCENDING endda DESCENDING.

  LOOP AT gt_vac ASSIGNING FIELD-SYMBOL(<fs_vac>).

    DATA ls_quota TYPE ty_quota.
    DATA lv_salbas_num TYPE p LENGTH 15 DECIMALS 2.
    DATA lv_valeve_num TYPE p LENGTH 15 DECIMALS 2.

    PERFORM f_find_quota
      TABLES gt_quota
      USING <fs_vac>-pernr <fs_vac>-begda
      CHANGING ls_quota.

    PERFORM f_get_salary_base
      TABLES gt_salary
      USING <fs_vac>-pernr <fs_vac>-begda
      CHANGING lv_salbas_num.

    lv_valeve_num = lv_salbas_num / 30 * <fs_vac>-abwtg.

    DATA lv_numemp TYPE string.
    DATA lv_tipcol TYPE string.
    DATA lv_numcad TYPE string.
    DATA lv_iniper TYPE string.
    DATA lv_inifer TYPE string.
    DATA lv_tabeve TYPE string.
    DATA lv_codeve TYPE string.
    DATA lv_refeve TYPE string.
    DATA lv_valeve TYPE string.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_vac>-persg
      CHANGING lv_tipcol.

    lv_numemp = <fs_vac>-bukrs.
    lv_numcad = |{ <fs_vac>-pernr ALPHA = OUT }|.
    lv_tabeve = '1'.
    lv_codeve = <fs_vac>-awart.

    PERFORM f_format_date USING ls_quota-begda CHANGING lv_iniper.
    PERFORM f_format_date USING <fs_vac>-begda CHANGING lv_inifer.
    PERFORM f_format_amount USING <fs_vac>-abwtg CHANGING lv_refeve.
    PERFORM f_format_amount USING lv_valeve_num CHANGING lv_valeve.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_iniper 10 CHANGING lv_iniper.
    PERFORM f_fit_field USING lv_inifer 10 CHANGING lv_inifer.
    PERFORM f_fit_field USING lv_tabeve 3 CHANGING lv_tabeve.
    PERFORM f_fit_field USING lv_codeve 4 CHANGING lv_codeve.
    PERFORM f_fit_field USING lv_refeve 12 CHANGING lv_refeve.
    PERFORM f_fit_field USING lv_valeve 12 CHANGING lv_valeve.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_iniper
      lv_inifer
      lv_tabeve
      lv_codeve
      lv_refeve
      lv_valeve
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1034 gerado:', gv_filename.

ENDFORM.

FORM f_find_quota
  TABLES pt_quota STRUCTURE ty_quota
  USING    pv_pernr TYPE pernr_d
           pv_date  TYPE datum
  CHANGING ps_quota TYPE ty_quota.

  CLEAR ps_quota.
  LOOP AT pt_quota INTO DATA(ls_quota) WHERE pernr = pv_pernr.
    IF ls_quota-begda <= pv_date AND ls_quota-endda >= pv_date.
      ps_quota = ls_quota.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_get_salary_base
  TABLES pt_salary STRUCTURE ty_salary
  USING    pv_pernr TYPE pernr_d
           pv_date  TYPE datum
  CHANGING pv_salbas TYPE p.

  CLEAR pv_salbas.
  LOOP AT pt_salary INTO DATA(ls_salary) WHERE pernr = pv_pernr.
    IF ls_salary-begda <= pv_date AND ls_salary-endda >= pv_date.
      pv_salbas = ls_salary-bet01.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_format_date
  USING    pv_date TYPE datum
  CHANGING pv_text TYPE string.

  CLEAR pv_text.
  IF pv_date IS INITIAL OR pv_date = '00000000'.
    RETURN.
  ENDIF.

  PERFORM f_conv_date IN PROGRAM zhr_export_senior
    USING pv_date
    CHANGING pv_text.

ENDFORM.

FORM f_format_amount
  USING    pv_value TYPE any
  CHANGING pv_text  TYPE string.

  DATA lv_value TYPE p LENGTH 15 DECIMALS 2.

  CLEAR pv_text.
  lv_value = pv_value.
  WRITE lv_value TO pv_text DECIMALS 2 NO-GROUPING.
  CONDENSE pv_text NO-GAPS.
  REPLACE ALL OCCURRENCES OF '.' IN pv_text WITH ','.

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

  IF pv_length > 0 AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.
