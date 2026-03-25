REPORT zhr_senior_exp_1005.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

DATA: gv_filename TYPE string,
      gv_header   TYPE string,
      gv_line     TYPE string,
      gt_file     TYPE STANDARD TABLE OF string,
      gv_count    TYPE i.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM build_filename.
  PERFORM build_header.
  PERFORM get_data.
  WRITE: / 'Arquivo gerado:', gv_filename.
  WRITE: / 'Registros exportados:', gv_count.

FORM build_filename.
  gv_filename = sy-datum && '_SENIOR_1005.csv'.
ENDFORM.

FORM build_header.
  gv_header = 'CODNOT;DESNOT;MOSFIC;BASLEG;TPESOC;SALVAR;APRGRA'.
ENDFORM.

FORM get_data.

  DATA: lv_codnot TYPE string,
        lv_desnot TYPE string,
        lv_mosfic TYPE string,
        lv_basleg TYPE string,
        lv_tpesoc TYPE string,
        lv_salvar TYPE string,
        lv_aprgra TYPE string.

  SELECT DISTINCT mgtxt
    INTO TABLE @DATA(lt_notas)
    FROM t530t
   WHERE sprsl = @sy-langu
     AND mgtxt <> @space.

  IF lt_notas IS INITIAL AND sy-langu <> 'P'.
    SELECT DISTINCT mgtxt
      INTO TABLE @lt_notas
      FROM t530t
     WHERE sprsl = 'P'
       AND mgtxt <> @space.
  ENDIF.

  IF lt_notas IS INITIAL.
    SELECT DISTINCT mgtxt
      INTO TABLE @lt_notas
      FROM t530t
     WHERE mgtxt <> @space.
  ENDIF.

  IF lt_notas IS INITIAL.
    MESSAGE 'Nenhum tipo de anotacao encontrado na T530T.' TYPE 'E'.
  ENDIF.

  SORT lt_notas BY table_line.
  DELETE ADJACENT DUPLICATES FROM lt_notas COMPARING table_line.

  APPEND gv_header TO gt_file.

  LOOP AT lt_notas INTO DATA(lv_nota).

    ADD 1 TO gv_count.

    IF gv_count > 999.
      MESSAGE 'Quantidade de tipos de anotacao excede o limite do layout 1005.' TYPE 'E'.
    ENDIF.

    CLEAR: lv_codnot, lv_desnot, lv_mosfic, lv_basleg, lv_tpesoc,
           lv_salvar, lv_aprgra, gv_line.

    lv_codnot = gv_count.
    PERFORM f_fit_field USING lv_codnot 3 CHANGING lv_codnot.

    lv_desnot = lv_nota.
    PERFORM f_fit_field USING lv_desnot 30 CHANGING lv_desnot.

    PERFORM f_derivar_tpesoc
      USING lv_nota
      CHANGING lv_tpesoc lv_mosfic lv_basleg lv_salvar lv_aprgra.

    PERFORM f_fit_field USING lv_mosfic 1 CHANGING lv_mosfic.
    PERFORM f_fit_field USING lv_basleg 1 CHANGING lv_basleg.
    PERFORM f_fit_field USING lv_tpesoc 20 CHANGING lv_tpesoc.
    PERFORM f_fit_field USING lv_salvar 1 CHANGING lv_salvar.
    PERFORM f_fit_field USING lv_aprgra 1 CHANGING lv_aprgra.

    gv_line =
      lv_codnot && ';' &&
      lv_desnot && ';' &&
      lv_mosfic && ';' &&
      lv_basleg && ';' &&
      lv_tpesoc && ';' &&
      lv_salvar && ';' &&
      lv_aprgra.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.
ENDFORM.

FORM f_fit_field USING    p_value  TYPE any
                          p_length TYPE i
                 CHANGING p_out    TYPE string.

  p_out = p_value.

  REPLACE ALL OCCURRENCES OF ';' IN p_out WITH ','.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN p_out WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN p_out WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN p_out WITH space.
  CONDENSE p_out.

  IF p_length > 0 AND strlen( p_out ) > p_length.
    p_out = p_out(p_length).
  ENDIF.

ENDFORM.

FORM f_derivar_tpesoc USING    p_desnot TYPE string
                      CHANGING p_tpesoc TYPE string
                               p_mosfic TYPE string
                               p_basleg TYPE string
                               p_salvar TYPE string
                               p_aprgra TYPE string.

  DATA lv_text TYPE string.

  CLEAR: p_tpesoc, p_mosfic, p_basleg, p_salvar, p_aprgra.

  lv_text = p_desnot.
  TRANSLATE lv_text TO UPPER CASE.

  p_tpesoc = '0'.
  p_mosfic = 'N'.

  IF lv_text CS 'ADVERT'.
    p_tpesoc = '1'.
    p_mosfic = 'S'.
  ELSEIF lv_text CS 'SUSPEN'.
    p_tpesoc = '2'.
    p_mosfic = 'S'.
  ELSEIF lv_text CS 'APOSENT'.
    p_tpesoc = '3'.
    p_mosfic = 'S'.
  ELSEIF lv_text CS 'SUCESS'
      OR lv_text CS 'INCORPOR'
      OR lv_text CS 'CISA'
      OR lv_text CS 'FUSA'.
    p_tpesoc = '6'.
    p_mosfic = 'S'.
  ELSEIF lv_text CS 'SALAR'.
    p_tpesoc = '7'.
    IF lv_text CS 'INIC'.
      p_salvar = '1'.
    ELSEIF lv_text CS 'FIM'
        OR lv_text CS 'TERM'.
      p_salvar = '2'.
    ENDIF.
  ELSEIF lv_text CS 'DEFIC'
      OR lv_text CS 'PCD'.
    p_tpesoc = '8'.
    p_mosfic = 'S'.
  ELSEIF lv_text CS 'JORNAD'
      OR lv_text CS 'HORAR'
      OR lv_text CS 'CARGA HOR'.
    p_tpesoc = '10'.
  ELSEIF lv_text CS 'CONTRAT'.
    p_tpesoc = '11'.
    p_mosfic = 'S'.
  ENDIF.

  IF lv_text CS 'ART. 62'
      OR lv_text CS 'ART 62'
      OR lv_text CS '235 C'
      OR lv_text CS '235C'.
    IF lv_text CS 'INCISO I'.
      IF lv_text CS 'FIM'
          OR lv_text CS 'TERM'.
        p_basleg = '2'.
      ELSE.
        p_basleg = '1'.
      ENDIF.
    ELSEIF lv_text CS 'INCISO II'.
      IF lv_text CS 'FIM'
          OR lv_text CS 'TERM'.
        p_basleg = '4'.
      ELSE.
        p_basleg = '3'.
      ENDIF.
    ELSEIF lv_text CS 'INCISO III'.
      IF lv_text CS 'FIM'
          OR lv_text CS 'TERM'.
        p_basleg = '6'.
      ELSE.
        p_basleg = '5'.
      ENDIF.
    ELSEIF lv_text CS '235 C'
        OR lv_text CS '235C'.
      IF lv_text CS 'FIM'
          OR lv_text CS 'TERM'.
        p_basleg = '8'.
      ELSE.
        p_basleg = '7'.
      ENDIF.
    ENDIF.
  ENDIF.

  IF lv_text CS 'APREND'
      AND lv_text CS 'GRAVID'.
    p_aprgra = 'S'.
  ENDIF.

ENDFORM.
