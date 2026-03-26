REPORT zhr_senior_exp_1011.

TYPES: BEGIN OF ty_addr_source,
         adrnr  TYPE adrc-addrnumber,
         nombai TYPE string,
         cepbai TYPE string,
       END OF ty_addr_source,
       BEGIN OF ty_adrc,
         addrnumber TYPE adrc-addrnumber,
         taxjurcode TYPE adrc-taxjurcode,
         city_code  TYPE adrc-city_code,
         city2      TYPE adrc-city2,
         post_code1 TYPE adrc-post_code1,
       END OF ty_adrc,
       BEGIN OF ty_bairro,
         codcid TYPE string,
         nombai TYPE string,
         cepbai TYPE string,
       END OF ty_bairro.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

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
        gt_file     TYPE STANDARD TABLE OF string,
        gt_source   TYPE STANDARD TABLE OF ty_addr_source,
        gt_adrc     TYPE STANDARD TABLE OF ty_adrc,
        gt_bairro   TYPE STANDARD TABLE OF ty_bairro.

  DATA: lv_codcid TYPE string,
        lv_codbai TYPE string,
        lv_nombai TYPE string,
        lv_cepbai TYPE string,
        lv_seq    TYPE i,
        lv_city   TYPE string.

  DATA: address       LIKE sadr,
        branch_record LIKE j_1bbranch,
        cgc_number    LIKE j_1bwfield-cgc_number.

  FIELD-SYMBOLS: <fs_adrnr> TYPE any.

  gv_filename = sy-datum && '_SENIOR_1011.csv'.
  gv_header = 'CODCID;CODBAI;NOMBAI;CEPBAI'.

  SELECT *
    INTO TABLE @DATA(gt_0006)
    FROM pa0006
   WHERE begda <= @sy-datum
     AND endda >= @sy-datum
     AND ort02 <> @space.

  LOOP AT gt_0006 ASSIGNING FIELD-SYMBOL(<fs_0006>).
    ASSIGN COMPONENT 'ADRNR' OF STRUCTURE <fs_0006> TO <fs_adrnr>.
    IF sy-subrc = 0
       AND <fs_adrnr> IS ASSIGNED
       AND <fs_adrnr> IS NOT INITIAL.
      APPEND VALUE ty_addr_source(
        adrnr  = <fs_adrnr>
        nombai = <fs_0006>-ort02
        cepbai = <fs_0006>-pstlz ) TO gt_source.
    ENDIF.
  ENDLOOP.

  SELECT bukrs
    INTO TABLE @DATA(gt_t001)
    FROM t001
   WHERE bukrs LIKE 'BR%'.

  IF gt_t001 IS NOT INITIAL.
    SELECT *
      INTO TABLE @DATA(gt_branch)
      FROM j_1bbranch
      FOR ALL ENTRIES IN @gt_t001
     WHERE bukrs = @gt_t001-bukrs.

    LOOP AT gt_branch ASSIGNING FIELD-SYMBOL(<fs_branch>).
      CLEAR: address, branch_record, cgc_number.

      CALL FUNCTION 'J_1B_BRANCH_READ'
        EXPORTING
          branch            = <fs_branch>-branch
          company           = <fs_branch>-bukrs
        IMPORTING
          address           = address
          branch_record     = branch_record
          cgc_number        = cgc_number
        EXCEPTIONS
          branch_not_found  = 1
          address_not_found = 2
          company_not_found = 3
          OTHERS            = 4.

      IF sy-subrc = 0 AND address-adrnr IS NOT INITIAL.
        APPEND VALUE ty_addr_source(
          adrnr = address-adrnr ) TO gt_source.
      ENDIF.
    ENDLOOP.
  ENDIF.

  SORT gt_source BY adrnr nombai cepbai.
  DELETE ADJACENT DUPLICATES FROM gt_source COMPARING adrnr nombai
cepbai.

  IF gt_source IS NOT INITIAL.
    SELECT addrnumber,
           taxjurcode,
           city_code,
           city2,
           post_code1
      INTO TABLE @gt_adrc
      FROM adrc
      FOR ALL ENTRIES IN @gt_source
     WHERE addrnumber = @gt_source-adrnr
       AND nation     = @space.
  ENDIF.

  SORT gt_adrc BY addrnumber.

  APPEND gv_header TO gt_file.

  LOOP AT gt_source ASSIGNING FIELD-SYMBOL(<fs_source>).

    CLEAR: lv_codcid, lv_nombai, lv_cepbai.

    READ TABLE gt_adrc ASSIGNING FIELD-SYMBOL(<fs_adrc>)
      WITH KEY addrnumber = <fs_source>-adrnr
      BINARY SEARCH.

    IF sy-subrc = 0.
      lv_codcid = <fs_adrc>-taxjurcode.
      IF lv_codcid IS INITIAL.
        lv_codcid = <fs_adrc>-city_code.
      ENDIF.
      lv_nombai = <fs_adrc>-city2.
      lv_cepbai = <fs_adrc>-post_code1.
    ENDIF.

    IF lv_nombai IS INITIAL.
      lv_nombai = <fs_source>-nombai.
    ENDIF.

    IF lv_cepbai IS INITIAL.
      lv_cepbai = <fs_source>-cepbai.
    ENDIF.

    PERFORM f_remove_mask IN PROGRAM zhr_export_senior
      USING lv_codcid
      CHANGING lv_codcid.

    PERFORM f_remove_mask IN PROGRAM zhr_export_senior
      USING lv_cepbai
      CHANGING lv_cepbai.

    IF strlen( lv_codcid ) <> 7.
      CONTINUE.
    ENDIF.

    IF lv_nombai IS INITIAL.
      lv_nombai = 'SEM BAIRRO'.
    ENDIF.

    IF lv_cepbai IS INITIAL.
      CONTINUE.
    ENDIF.

    PERFORM f_fit_field USING lv_nombai 40 CHANGING lv_nombai.
    PERFORM f_fit_field USING lv_cepbai 8 CHANGING lv_cepbai.

    APPEND VALUE ty_bairro(
      codcid = lv_codcid
      nombai = lv_nombai
      cepbai = lv_cepbai ) TO gt_bairro.

  ENDLOOP.

  SORT gt_bairro BY codcid nombai cepbai.
  DELETE ADJACENT DUPLICATES FROM gt_bairro COMPARING codcid nombai
cepbai.

  IF gt_bairro IS INITIAL.
    PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING
gv_filename CHANGING gt_file p_locl p_serv.
    WRITE: / 'Layout 1011 gerado sem bairros com codigo IBGE valido.'.
    RETURN.
  ENDIF.

  CLEAR: lv_city, lv_seq.

  LOOP AT gt_bairro ASSIGNING FIELD-SYMBOL(<fs_bairro>).

    IF lv_city <> <fs_bairro>-codcid.
      lv_city = <fs_bairro>-codcid.
      CLEAR lv_seq.
    ENDIF.

    ADD 1 TO lv_seq.

    IF lv_seq > 9999.
MESSAGE 'Qtd de bairros excede limite por cidade no layout.'
 TYPE 'E'.
    ENDIF.

    lv_codbai = lv_seq.
    PERFORM f_fit_field USING lv_codbai 4 CHANGING lv_codbai.

    gv_line =
      <fs_bairro>-codcid && ';' &&
      lv_codbai         && ';' &&
      <fs_bairro>-nombai && ';' &&
      <fs_bairro>-cepbai.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING
gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1011 gerado:', gv_filename.

ENDFORM.

FORM f_fit_field USING    p_value TYPE string
                          p_len   TYPE i
                 CHANGING p_out   TYPE string.

  p_out = p_value.

  REPLACE ALL OCCURRENCES OF ';' IN p_out WITH ','.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN p_out WITH
space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN p_out
WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN
p_out WITH space.
  CONDENSE p_out.

  IF p_len > 0 AND strlen( p_out ) > p_len.
    p_out = p_out(p_len).
  ENDIF.

ENDFORM.
