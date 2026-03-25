REPORT zhr_export_senior_1009.

PARAMETERS:
  p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = p_serv && sy-datum && '_SENIOR_1009.csv'.

  gv_header = 'CODSIN;NOMSIN;SIGSIN;MESDIS;ENTALF;NUMCGC;ENDRUA;ENDNUM;ENDCPL;CODCID;ENDCEP;CODBAI;CODENT;CFJCGC'.

*---------------------------------------------------------------------*
* Seleção sindicatos
*---------------------------------------------------------------------*

  SELECT
    t521b~emfsl,   " Código sindicato
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

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo.' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

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
* SIGLA (gerar se não existir)
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
* CNPJ numérico (NUMCGC)
*---------------------------------------------------------------------*

    lv_cnpj = <fs_sind>-uncgc.

    REPLACE ALL OCCURRENCES OF '.' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '/' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '-' IN lv_cnpj WITH ''.

*---------------------------------------------------------------------*
* CNPJ alfanumérico (CFJCGC)
*---------------------------------------------------------------------*

    lv_cnpj_a = lv_cnpj.

*---------------------------------------------------------------------*
* CODENT (até 12 posições)
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
      ''                 && ';' && " ENDNUM (não separado no SAP)
      ''                 && ';' && " ENDCPL
      <fs_sind>-ort01    && ';' && " CODCID
      <fs_sind>-pstlz    && ';' && " ENDCEP
      ''                 && ';' && " CODBAI
      lv_codent          && ';' && " CODENT
      lv_cnpj_a.                    " CFJCGC

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
