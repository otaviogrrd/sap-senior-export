REPORT zhr_senior_exp_1003.

TYPES: BEGIN OF ty_oem,
         lifnr      TYPE lfa1-lifnr,
         name1      TYPE lfa1-name1,
         sortl      TYPE lfa1-sortl,
         stcd1      TYPE lfa1-stcd1,
         stcd2      TYPE lfa1-stcd2,
         stcd3      TYPE lfa1-stcd3,
         adrnr      TYPE lfa1-adrnr,
         region     TYPE adrc-region,
         city_code  TYPE adrc-city_code,
         street     TYPE adrc-street,
         str_suppl1 TYPE adrc-str_suppl1,
         house_num1 TYPE adrc-house_num1,
         post_code1 TYPE adrc-post_code1,
         city2      TYPE adrc-city2,
         city1      TYPE adrc-city1,
         country    TYPE adrc-country,
       END OF ty_oem,
       BEGIN OF ty_phone,
         addrnumber TYPE adr2-addrnumber,
         tel_number TYPE adr2-tel_number,
       END OF ty_phone.

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
        gt_oem      TYPE STANDARD TABLE OF ty_oem,
        gt_phone    TYPE STANDARD TABLE OF ty_phone.

  DATA: lv_codoem    TYPE string,
        lv_nomoem    TYPE string,
        lv_apeoem    TYPE string,
        lv_codcid    TYPE string,
        lv_endoem    TYPE string,
        lv_endcpl    TYPE string,
        lv_endnum    TYPE string,
        lv_dditel    TYPE string,
        lv_dddtel    TYPE string,
        lv_numtel    TYPE string,
        lv_tipins    TYPE c LENGTH 1,
        lv_numcgc    TYPE string,
        lv_insest    TYPE string,
        lv_tiplgr    TYPE string,
        lv_codcep    TYPE string,
        lv_codbai    TYPE string,
        lv_codpai    TYPE string,
        lv_cfjcgc    TYPE string,
        lv_tax_id    TYPE string,
        lv_tax_clean TYPE string,
        lv_phone     TYPE string.

  gv_filename = sy-datum && '_1003.csv'.
  gv_header = 'CODOEM;NOMOEM;APEOEM;CODEST;CODCID;ENDOEM;ENDCPL;'
  && 'ENDNUM;DDITEL;DDDTEL;NUMTEL;TIPINS;NUMCGC;INSEST;'
  && 'TIPLGR;CODCEP;CODBAI;CODPAI;CFJCGC'.

  SELECT lfa1~lifnr,
         lfa1~name1,
         lfa1~sortl,
         lfa1~stcd1,
         lfa1~stcd2,
         lfa1~stcd3,
         lfa1~adrnr,
         adrc~region,
         adrc~city_code,
         adrc~street,
         adrc~str_suppl1,
         adrc~house_num1,
         adrc~post_code1,
         adrc~city2,
         adrc~city1,
         adrc~country
    INTO TABLE @gt_oem
    FROM lfa1 AS lfa1
    LEFT JOIN adrc AS adrc
      ON adrc~addrnumber = lfa1~adrnr
     AND adrc~nation     = @space
   WHERE lfa1~loevm = @space
     AND ( lfa1~stcd1 <> @space OR lfa1~stcd2 <> @space ).

  IF sy-subrc <> 0 OR gt_oem IS INITIAL.
    MESSAGE 'Nenhuma outra empresa encontrada em LFA1.' TYPE 'E'.
  ENDIF.

  SELECT addrnumber,
         tel_number
    INTO TABLE @gt_phone
    FROM adr2
    FOR ALL ENTRIES IN @gt_oem
   WHERE addrnumber = @gt_oem-adrnr
     AND tel_number <> @space.

  SORT gt_phone BY addrnumber.
  DELETE ADJACENT DUPLICATES FROM gt_phone COMPARING addrnumber.

  APPEND gv_header TO gt_file.

  SORT gt_oem BY lifnr.

  LOOP AT gt_oem ASSIGNING FIELD-SYMBOL(<fs_oem>).

    CLEAR: lv_codoem, lv_nomoem, lv_apeoem, lv_codcid, lv_endoem,
           lv_endcpl, lv_endnum, lv_dditel, lv_dddtel, lv_numtel,
           lv_tipins, lv_numcgc, lv_insest, lv_tiplgr, lv_codcep,
           lv_codbai, lv_codpai, lv_cfjcgc, lv_tax_id, lv_tax_clean,
           lv_phone.

    lv_codoem = |{ <fs_oem>-lifnr ALPHA = OUT }|.
    CONDENSE lv_codoem NO-GAPS.

    lv_tax_id = <fs_oem>-stcd1.
    IF lv_tax_id IS INITIAL.
      lv_tax_id = <fs_oem>-stcd2.
    ENDIF.

    PERFORM f_remove_mask IN PROGRAM zhr_export_senior
      USING lv_tax_id
      CHANGING lv_tax_clean.

    IF lv_tax_clean IS INITIAL.
      CONTINUE.
    ENDIF.

    CASE strlen( lv_tax_clean ).
      WHEN 11.
        lv_tipins = '3'.
      WHEN 12.
        lv_tipins = '2'.
      WHEN OTHERS.
        lv_tipins = '1'.
    ENDCASE.

    lv_numcgc = lv_tax_clean.
    lv_cfjcgc = lv_tax_clean.

    lv_nomoem = <fs_oem>-name1.
    lv_apeoem = <fs_oem>-sortl.
    IF lv_apeoem IS INITIAL.
      lv_apeoem = lv_nomoem.
    ENDIF.

    PERFORM f_sanitize_text USING lv_nomoem CHANGING lv_nomoem.
    PERFORM f_sanitize_text USING lv_apeoem CHANGING lv_apeoem.

    lv_codcid = <fs_oem>-city_code.
    PERFORM f_remove_mask IN PROGRAM zhr_export_senior
      USING lv_codcid
      CHANGING lv_codcid.

    lv_endnum = <fs_oem>-house_num1.
    PERFORM f_sanitize_text USING lv_endnum CHANGING lv_endnum.

    lv_endcpl = <fs_oem>-str_suppl1.
    PERFORM f_sanitize_text USING lv_endcpl CHANGING lv_endcpl.

    PERFORM f_split_logradouro
      USING <fs_oem>-street
      CHANGING lv_tiplgr lv_endoem.

    lv_codcep = <fs_oem>-post_code1.
    PERFORM f_remove_mask IN PROGRAM zhr_export_senior
      USING lv_codcep
      CHANGING lv_codcep.

    lv_codbai = <fs_oem>-city2.
    IF lv_codbai IS INITIAL.
      lv_codbai = <fs_oem>-city1.
    ENDIF.
    IF lv_codbai IS INITIAL.
      lv_codbai = 'NAO INFORMADO'.
    ENDIF.
    PERFORM f_sanitize_text USING lv_codbai CHANGING lv_codbai.

    lv_insest = <fs_oem>-stcd3.
    PERFORM f_sanitize_text USING lv_insest CHANGING lv_insest.

    lv_codpai = '1'.

    READ TABLE gt_phone ASSIGNING FIELD-SYMBOL(<fs_phone>)
      WITH KEY addrnumber = <fs_oem>-adrnr
      BINARY SEARCH.
    IF sy-subrc = 0.
      lv_phone = <fs_phone>-tel_number.
    ENDIF.

    PERFORM f_parse_phone
      USING lv_phone <fs_oem>-country
      CHANGING lv_dditel lv_dddtel lv_numtel.

    gv_line =
      lv_codoem       && ';' &&
      lv_nomoem       && ';' &&
      lv_apeoem       && ';' &&
      <fs_oem>-region && ';' &&
      lv_codcid       && ';' &&
      lv_endoem       && ';' &&
      lv_endcpl       && ';' &&
      lv_endnum       && ';' &&
      lv_dditel       && ';' &&
      lv_dddtel       && ';' &&
      lv_numtel       && ';' &&
      lv_tipins       && ';' &&
      lv_numcgc       && ';' &&
      lv_insest       && ';' &&
      lv_tiplgr       && ';' &&
      lv_codcep       && ';' &&
      lv_codbai       && ';' &&
      lv_codpai       && ';' &&
      lv_cfjcgc.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Layout 1003 gerado:', gv_filename.

ENDFORM.

FORM f_sanitize_text USING    p_value TYPE string
                     CHANGING p_clean TYPE string.

  p_clean = p_value.

  REPLACE ALL OCCURRENCES OF ';' IN p_clean WITH ','.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN p_clean WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN p_clean WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN p_clean WITH space.
  CONDENSE p_clean.

ENDFORM.

FORM f_split_logradouro USING    p_street TYPE string
                        CHANGING p_tiplgr TYPE string
                                 p_endoem TYPE string.

  DATA lv_street TYPE string.

  p_tiplgr = ''.
  p_endoem = p_street.
  CONDENSE p_endoem.

  lv_street = p_endoem.
  TRANSLATE lv_street TO UPPER CASE.

  IF lv_street CP 'RUA *'.
    p_tiplgr = 'R'.
    p_endoem = p_endoem+4.
  ELSEIF lv_street CP 'R. *'.
    p_tiplgr = 'R'.
    p_endoem = p_endoem+3.
  ELSEIF lv_street CP 'AVENIDA *'.
    p_tiplgr = 'AV'.
    p_endoem = p_endoem+8.
  ELSEIF lv_street CP 'AV. *'.
    p_tiplgr = 'AV'.
    p_endoem = p_endoem+4.
  ELSEIF lv_street CP 'ALAMEDA *'.
    p_tiplgr = 'AL'.
    p_endoem = p_endoem+8.
  ELSEIF lv_street CP 'TRAVESSA *'.
    p_tiplgr = 'TV'.
    p_endoem = p_endoem+9.
  ELSEIF lv_street CP 'RODOVIA *'.
    p_tiplgr = 'ROD'.
    p_endoem = p_endoem+8.
  ELSEIF lv_street CP 'ESTRADA *'.
    p_tiplgr = 'EST'.
    p_endoem = p_endoem+8.
  ENDIF.

  CONDENSE p_endoem.
  PERFORM f_sanitize_text USING p_endoem CHANGING p_endoem.

ENDFORM.

FORM f_parse_phone USING    p_phone   TYPE string
                            p_country TYPE adrc-country
                   CHANGING p_ddi     TYPE string
                            p_ddd     TYPE string
                            p_num     TYPE string.

  DATA lv_phone TYPE string.

  CLEAR: p_ddi, p_ddd, p_num.

  PERFORM f_remove_mask IN PROGRAM zhr_export_senior
    USING p_phone
    CHANGING lv_phone.

  IF lv_phone IS INITIAL.
    RETURN.
  ENDIF.

  IF strlen( lv_phone ) >= 12 AND lv_phone(2) = '55'.
    p_ddi = lv_phone(2).
    p_ddd = lv_phone+2(2).
    p_num = lv_phone+4.
  ELSEIF strlen( lv_phone ) >= 10.
    IF p_country = 'BR' OR p_country IS INITIAL.
      p_ddi = '55'.
    ENDIF.
    p_ddd = lv_phone(2).
    p_num = lv_phone+2.
  ELSE.
    p_num = lv_phone.
  ENDIF.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA lv_folder TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_folder IS NOT INITIAL.
    p_locl = lv_folder.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_folder   TYPE string,
    lv_server   TYPE string,
    lv_fullpath TYPE string,
    lv_line     TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.

  lv_server = p_serv.

  IF lv_server IS NOT INITIAL.
    lv_len = strlen( lv_server ) - 1.
    IF lv_len >= 0.
      lv_last = lv_server+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_server '/' INTO lv_server.
      ENDIF.
    ENDIF.

    CONCATENATE lv_server pv_filename INTO lv_fullpath.

    OPEN DATASET lv_fullpath FOR OUTPUT
      IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo no servidor.' TYPE 'E'.
    ENDIF.

    LOOP AT pt_file INTO lv_line.
      TRANSFER lv_line TO lv_fullpath.
    ENDLOOP.

    CLOSE DATASET lv_fullpath.
    p_serv = lv_server.
    RETURN.
  ENDIF.

  lv_folder = p_locl.

  IF lv_folder IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>directory_browse
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_folder IS INITIAL.
      MESSAGE 'Selecao de diretorio cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  lv_len = strlen( lv_folder ) - 1.
  IF lv_len >= 0.
    lv_last = lv_folder+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE lv_folder '\' INTO lv_folder.
    ENDIF.
  ENDIF.

  CONCATENATE lv_folder pv_filename INTO lv_fullpath.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

  p_locl = lv_folder.

ENDFORM.
