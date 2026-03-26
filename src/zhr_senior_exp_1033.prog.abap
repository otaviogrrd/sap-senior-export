REPORT zhr_senior_exp_1033.

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
         endda TYPE endda,
         awart TYPE pa2001-awart,
         abwtg TYPE pa2001-abwtg,
       END OF ty_vac.

TYPES: BEGIN OF ty_salary,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
         bet01 TYPE pa0008-bet01,
       END OF ty_salary.

TYPES ty_t_quota  TYPE STANDARD TABLE OF ty_quota WITH DEFAULT KEY.
TYPES ty_t_salary TYPE STANDARD TABLE OF ty_salary WITH DEFAULT KEY.

DATA: gt_quota  TYPE STANDARD TABLE OF ty_quota,
      gt_salary TYPE STANDARD TABLE OF ty_salary.

TYPES: BEGIN OF ty_master,
         pernr   TYPE pernr_d,
         bukrs   TYPE bukrs,
         persg   TYPE persg,
         iniper  TYPE begda,
         inifer  TYPE begda,
         tipfer  TYPE c LENGTH 1,
         datpag  TYPE datum,
         diafer  TYPE p LENGTH 8 DECIMALS 2,
         diaabo  TYPE p LENGTH 8 DECIMALS 2,
         salbas  TYPE p LENGTH 15 DECIMALS 2,
       END OF ty_master.

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

  DATA: gt_vac    TYPE STANDARD TABLE OF ty_vac,
        gt_master TYPE STANDARD TABLE OF ty_master.

  gv_filename = sy-datum && '_SENIOR_1033.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;INIPER;INIFER;TIPFER;OPC13S;'
  && 'DATPAG;DIAFER;DIAABO;SalBas'.

  APPEND gv_header TO gt_file.

  SELECT pernr, begda, endda
    INTO TABLE @gt_quota
    FROM pa2006.

  SELECT
    p2001~pernr,
    p1~bukrs,
    p1~persg,
    p2001~begda,
    p2001~endda,
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
    WRITE: / 'Layout 1033 gerado:', gv_filename.
    RETURN.
  ENDIF.

  SELECT pernr, begda, endda, bet01
    INTO TABLE @gt_salary
    FROM pa0008
    FOR ALL ENTRIES IN @gt_vac
   WHERE pernr = @gt_vac-pernr.

  SORT gt_quota BY pernr begda DESCENDING endda DESCENDING.
  SORT gt_vac BY pernr begda awart.
  SORT gt_salary BY pernr begda DESCENDING endda DESCENDING.

  LOOP AT gt_vac ASSIGNING FIELD-SYMBOL(<fs_vac>).

    DATA ls_quota TYPE ty_quota.
    DATA lv_salbas_num TYPE p LENGTH 15 DECIMALS 2.
    DATA lv_is_abono TYPE c LENGTH 1.
    DATA lv_tipfer TYPE string.
    DATA lv_iniper TYPE datum.
    DATA lv_datpag TYPE datum.

    PERFORM f_find_quota
      USING <fs_vac>-pernr <fs_vac>-begda
      CHANGING ls_quota.

    PERFORM f_get_salary_base
      USING <fs_vac>-pernr <fs_vac>-begda
      CHANGING lv_salbas_num.

    PERFORM f_is_abono_awart USING <fs_vac>-awart CHANGING lv_is_abono.
    PERFORM f_get_tipfer USING <fs_vac>-awart CHANGING lv_tipfer.

    lv_iniper = ls_quota-begda.
    IF lv_iniper IS INITIAL.
      lv_iniper = <fs_vac>-begda - 365.
    ENDIF.
    lv_datpag = <fs_vac>-begda - 2.

    READ TABLE gt_master ASSIGNING FIELD-SYMBOL(<fs_master>)
      WITH KEY pernr  = <fs_vac>-pernr
               iniper = lv_iniper
               inifer = <fs_vac>-begda
               tipfer = lv_tipfer
               datpag = lv_datpag.

    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO gt_master ASSIGNING <fs_master>.
      <fs_master>-pernr  = <fs_vac>-pernr.
      <fs_master>-bukrs  = <fs_vac>-bukrs.
      <fs_master>-persg  = <fs_vac>-persg.
      <fs_master>-iniper = lv_iniper.
      <fs_master>-inifer = <fs_vac>-begda.
      <fs_master>-tipfer = lv_tipfer.
      <fs_master>-datpag = lv_datpag.
      <fs_master>-salbas = lv_salbas_num.
    ENDIF.

    IF lv_is_abono = 'X'.
      <fs_master>-diaabo = <fs_master>-diaabo + <fs_vac>-abwtg.
    ELSE.
      <fs_master>-diafer = <fs_master>-diafer + <fs_vac>-abwtg.
    ENDIF.

    IF <fs_master>-salbas IS INITIAL.
      <fs_master>-salbas = lv_salbas_num.
    ENDIF.

  ENDLOOP.

  LOOP AT gt_master ASSIGNING <fs_master>.

    DATA lv_numemp TYPE string.
    DATA lv_tipcol TYPE string.
    DATA lv_numcad TYPE string.
    DATA lv_iniper_txt TYPE string.
    DATA lv_inifer_txt TYPE string.
    DATA lv_tipfer_txt TYPE string.
    DATA lv_opc13s TYPE string.
    DATA lv_datpag_txt TYPE string.
    DATA lv_diafer TYPE string.
    DATA lv_diaabo TYPE string.
    DATA lv_salbas TYPE string.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_master>-persg
      CHANGING lv_tipcol.

    lv_numemp = <fs_master>-bukrs.
    lv_numcad = |{ <fs_master>-pernr ALPHA = OUT }|.
    lv_tipfer_txt = <fs_master>-tipfer.
    lv_opc13s = 'N'.

    PERFORM f_format_date USING <fs_master>-iniper CHANGING lv_iniper_txt.
    PERFORM f_format_date USING <fs_master>-inifer CHANGING lv_inifer_txt.
    PERFORM f_format_date USING <fs_master>-datpag CHANGING lv_datpag_txt.
    PERFORM f_format_amount USING <fs_master>-diafer CHANGING lv_diafer.
    PERFORM f_format_amount USING <fs_master>-diaabo CHANGING lv_diaabo.
    PERFORM f_format_amount USING <fs_master>-salbas CHANGING lv_salbas.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_iniper_txt 10 CHANGING lv_iniper_txt.
    PERFORM f_fit_field USING lv_inifer_txt 10 CHANGING lv_inifer_txt.
    PERFORM f_fit_field USING lv_tipfer_txt 1 CHANGING lv_tipfer_txt.
    PERFORM f_fit_field USING lv_opc13s 1 CHANGING lv_opc13s.
    PERFORM f_fit_field USING lv_datpag_txt 10 CHANGING lv_datpag_txt.
    PERFORM f_fit_field USING lv_diafer 5 CHANGING lv_diafer.
    PERFORM f_fit_field USING lv_diaabo 5 CHANGING lv_diaabo.
    PERFORM f_fit_field USING lv_salbas 12 CHANGING lv_salbas.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_iniper_txt
      lv_inifer_txt
      lv_tipfer_txt
      lv_opc13s
      lv_datpag_txt
      lv_diafer
      lv_diaabo
      lv_salbas
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1033 gerado:', gv_filename.

ENDFORM.

FORM f_find_quota
  USING    pv_pernr TYPE pernr_d
           pv_date  TYPE datum
  CHANGING ps_quota TYPE ty_quota.

  DATA ls_quota TYPE ty_quota.

  CLEAR ps_quota.
  LOOP AT gt_quota INTO ls_quota WHERE pernr = pv_pernr.
    IF ls_quota-begda <= pv_date AND ls_quota-endda >= pv_date.
      ps_quota = ls_quota.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_get_salary_base
  USING    pv_pernr TYPE pernr_d
           pv_date  TYPE datum
  CHANGING pv_salbas TYPE p.

  DATA ls_salary TYPE ty_salary.

  CLEAR pv_salbas.
  LOOP AT gt_salary INTO ls_salary WHERE pernr = pv_pernr.
    IF ls_salary-begda <= pv_date AND ls_salary-endda >= pv_date.
      pv_salbas = ls_salary-bet01.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_get_tipfer
  USING    pv_awart TYPE pa2001-awart
  CHANGING pv_tipfer TYPE string.

  IF pv_awart = '9100' OR pv_awart = '9120'.
    pv_tipfer = 'C'.
  ELSE.
    pv_tipfer = 'N'.
  ENDIF.

ENDFORM.

FORM f_is_abono_awart
  USING    pv_awart TYPE pa2001-awart
  CHANGING pv_flag  TYPE c.

  CLEAR pv_flag.
  IF pv_awart = '0120'
     OR pv_awart = '0130'
     OR pv_awart = '0150'.
    pv_flag = 'X'.
  ENDIF.

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

  IF pv_length > 0 AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.
