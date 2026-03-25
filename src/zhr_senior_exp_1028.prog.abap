REPORT zhr_senior_exp_1028.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_hist,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         schkz TYPE pa0007-schkz,
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

  gv_filename = sy-datum && '_SENIOR_1028.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;CODESC;CODTMA'.

  APPEND gv_header TO gt_file.

  SELECT
    p7~pernr,
    p1~bukrs,
    p1~persg,
    p7~begda,
    p7~schkz
    INTO TABLE @gt_hist
    FROM pa0007 AS p7
    INNER JOIN pa0001 AS p1
      ON p1~pernr = p7~pernr
     AND p1~begda <= p7~begda
     AND p1~endda >= p7~begda
   WHERE p7~begda <= @sy-datum
     AND p7~schkz <> @space.

  SORT gt_hist BY pernr begda schkz.
  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda schkz.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

    DATA: lv_numemp TYPE string,
          lv_tipcol TYPE string,
          lv_numcad TYPE string,
          lv_datalt TYPE string,
          lv_codesc TYPE string,
          lv_codtma TYPE string.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_format_date USING <fs_hist>-begda CHANGING lv_datalt.

    lv_numemp = <fs_hist>-bukrs.
    lv_numcad = |{ <fs_hist>-pernr ALPHA = OUT }|.
    lv_codesc = <fs_hist>-schkz.
    lv_codtma = '1'.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_datalt 10 CHANGING lv_datalt.
    PERFORM f_fit_field USING lv_codesc 4 CHANGING lv_codesc.
    PERFORM f_fit_field USING lv_codtma 1 CHANGING lv_codtma.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_datalt
      lv_codesc
      lv_codtma
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1028 gerado:', gv_filename.

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
