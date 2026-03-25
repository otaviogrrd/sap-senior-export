REPORT zhr_senior_exp_1026.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_hist,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         empid TYPE pa0398-empid,
         fgtso TYPE pa0398-fgtso,
       END OF ty_hist.

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

  DATA gt_hist TYPE STANDARD TABLE OF ty_hist.

  gv_filename = sy-datum && '_SENIOR_1026.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;CATSEF'.

  APPEND gv_header TO gt_file.

  SELECT
    p398~pernr,
    p1~bukrs,
    p1~persg,
    p398~begda,
    p398~empid,
    p398~fgtso
    INTO TABLE @gt_hist
    FROM pa0398 AS p398
    INNER JOIN pa0001 AS p1
      ON p1~pernr = p398~pernr
     AND p1~begda <= p398~begda
     AND p1~endda >= p398~begda
   WHERE p398~begda <= @sy-datum.

  SORT gt_hist BY pernr begda empid fgtso.
  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda empid fgtso.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

    DATA: lv_numemp TYPE string,
          lv_tipcol TYPE string,
          lv_numcad TYPE string,
          lv_datalt TYPE string,
          lv_catsef TYPE string.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_map_catsef
      USING <fs_hist>-persg <fs_hist>-empid <fs_hist>-fgtso
      CHANGING lv_catsef.

    PERFORM f_format_date USING <fs_hist>-begda CHANGING lv_datalt.

    lv_numemp = <fs_hist>-bukrs.
    lv_numcad = |{ <fs_hist>-pernr ALPHA = OUT }|.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_datalt 10 CHANGING lv_datalt.
    PERFORM f_fit_field USING lv_catsef 2 CHANGING lv_catsef.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_datalt
      lv_catsef
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1026 gerado:', gv_filename.

ENDFORM.

FORM f_map_catsef
  USING    pv_persg TYPE persg
           pv_empid TYPE pa0398-empid
           pv_fgtso TYPE pa0398-fgtso
  CHANGING pv_catsef TYPE string.

  CLEAR pv_catsef.

  CASE pv_persg.
    WHEN '4'.
      pv_catsef = '7'.
    WHEN '5'.
      pv_catsef = '99'.
    WHEN '6'.
      pv_catsef = '13'.
    WHEN '7'.
      IF pv_fgtso = 'X' OR pv_empid = '05'.
        pv_catsef = '11'.
      ELSE.
        pv_catsef = '13'.
      ENDIF.
    WHEN OTHERS.
      pv_catsef = '1'.
  ENDCASE.

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
