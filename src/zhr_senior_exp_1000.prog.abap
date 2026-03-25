REPORT zhr_senior_exp_1000.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

FORM f_exportar_dados.

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string,
        gt_file     TYPE STANDARD TABLE OF string.

  gv_filename = sy-datum && '_SENIOR_1000.csv'.
  gv_header = 'NUMEMP;NOMEMP;APEEMP;DDITEL;DDDTEL;NUMTEL'.

  SELECT *
    INTO TABLE @DATA(tl_t001)
    FROM t001
   WHERE bukrs LIKE 'BR%'.

  IF sy-subrc NE 0.
    MESSAGE 'Nenhum dado encontrado na tabela SAP.' TYPE 'E'.
  ENDIF.

  APPEND gv_header TO gt_file.

  LOOP AT tl_t001 ASSIGNING FIELD-SYMBOL(<fs_t001>).

    gv_line = <fs_t001>-bukrs && ';' &&
              <fs_t001>-butxt && ';' &&
              <fs_t001>-butxt && ';' &&
              '00' && ';' &&
              '000' && ';' &&
              'N/E' .

    APPEND gv_line TO gt_file.
  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
