REPORT zhr_senior_exp_1009.

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

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1009.csv'.

  gv_header = 'CODSIN;NOMSIN;SIGSIN;MESDIS;ENTALF;NUMCGC;ENDRUA;'
  && 'ENDNUM;ENDCPL;CODCID;ENDCEP;CODBAI;CODENT;CFJCGC'.

*---------------------------------------------------------------------*
* Sele??o sindicatos
*---------------------------------------------------------------------*

  SELECT
    t521b~emfsl,   " C?digo sindicato
    t521b~etext,   " Nome
    t521b~stras,
    t521b~ort01,
    t521b~pstlz,
    t7br1b~basmo,
    t7br1b~sindi,
    t7br1b~uncgc

  INTO TABLE @DATA(gt_sind)

  FROM t521b AS t521b

  LEFT JOIN t7br1b
    ON t7br1b~sindi = t521b~emfsl.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_sigla  TYPE string,
    lv_mesdis TYPE c LENGTH 2,
    lv_cnpj   TYPE string,
    lv_cnpj_a TYPE string,
    lv_codent TYPE string.

  LOOP AT gt_sind ASSIGNING FIELD-SYMBOL(<fs_sind>).

*---------------------------------------------------------------------*
* SIGLA (gerar se n?o existir)
*---------------------------------------------------------------------*

    lv_sigla = ''.

    IF lv_sigla IS INITIAL.

      DATA(lt_words) = VALUE stringtab( ).
      SPLIT <fs_sind>-etext AT space INTO TABLE lt_words.

      LOOP AT lt_words INTO DATA(lv_word).
        lv_sigla = lv_sigla && lv_word+0(1).
      ENDLOOP.

    ENDIF.

*---------------------------------------------------------------------*
* MESDIS (LMesAno)
*---------------------------------------------------------------------*

    PERFORM f_conv_mes IN PROGRAM zhr_export_senior
      USING <fs_sind>-basmo
      CHANGING lv_mesdis.

*---------------------------------------------------------------------*
* CNPJ num?rico (NUMCGC)
*---------------------------------------------------------------------*

    lv_cnpj = <fs_sind>-uncgc.

    REPLACE ALL OCCURRENCES OF '.' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '/' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '-' IN lv_cnpj WITH ''.

*---------------------------------------------------------------------*
* CNPJ alfanum?rico (CFJCGC)
*---------------------------------------------------------------------*

    lv_cnpj_a = lv_cnpj.

*---------------------------------------------------------------------*
* CODENT (at? 12 posi??es)
*---------------------------------------------------------------------*

    lv_codent = <fs_sind>-sindi.

    IF strlen( lv_codent ) > 12.
      lv_codent = lv_codent+0(12).
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_sind>-emfsl    && ';' && " CODSIN
      <fs_sind>-etext    && ';' && " NOMSIN
      lv_sigla           && ';' && " SIGSIN
      lv_mesdis          && ';' && " MESDIS
      <fs_sind>-sindi    && ';' && " ENTALF
      lv_cnpj            && ';' && " NUMCGC
      <fs_sind>-stras    && ';' && " ENDRUA
      ''                 && ';' && " ENDNUM (n?o separado no SAP)
      ''                 && ';' && " ENDCPL
      <fs_sind>-ort01    && ';' && " CODCID
      <fs_sind>-pstlz    && ';' && " ENDCEP
      ''                 && ';' && " CODBAI
      lv_codent          && ';' && " CODENT
      lv_cnpj_a.                    " CFJCGC

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
