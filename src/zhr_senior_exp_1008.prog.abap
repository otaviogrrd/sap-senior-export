REPORT zhr_export_senior_1008.

PARAMETERS:
  p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho do servidor.' TYPE 'E'.
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

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = p_serv && sy-datum && '_SENIOR_1008.csv'.

  gv_header = 'CODBAN;CODAGE;NOMAGE;CODEST;CODCID;DIGAGE'.

*---------------------------------------------------------------------*
* Coletar dados do empregado (origem real das agências)
*---------------------------------------------------------------------*

  SELECT DISTINCT
    bankl
  INTO TABLE @DATA(gt_bankl)
  FROM pa0009
  WHERE bankl NE ''.

*---------------------------------------------------------------------*
* Ordenar e evitar duplicidade
*---------------------------------------------------------------------*

  SORT gt_bankl BY bankl.
  DELETE ADJACENT DUPLICATES FROM gt_bankl COMPARING bankl.

*---------------------------------------------------------------------*
* Buscar dados do banco
*---------------------------------------------------------------------*

  SELECT
    bankl,
    banka,
    ort01,
    provz
  INTO TABLE @DATA(gt_bnka)
  FROM bnka
  FOR ALL ENTRIES IN @gt_bankl
  WHERE bankl = @gt_bankl-bankl
    AND banks = 'BR'.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo.' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  LOOP AT gt_bankl ASSIGNING FIELD-SYMBOL(<fs_bank>).

    DATA: lv_codban TYPE string,
          lv_codage TYPE string,
          lv_nome   TYPE string,
          lv_estado TYPE string,
          lv_cidade TYPE string,
          lv_dig    TYPE string.

*---------------------------------------------------------------------*
* Banco / Agência
*---------------------------------------------------------------------*

    lv_codban = <fs_bank>-bankl(3).
    lv_codage = <fs_bank>-bankl+3.

*---------------------------------------------------------------------*
* Buscar dados BNKA
*---------------------------------------------------------------------*

    READ TABLE gt_bnka ASSIGNING FIELD-SYMBOL(<fs_bnka>)
      WITH KEY bankl = <fs_bank>-bankl.

    IF sy-subrc = 0.
      lv_nome   = <fs_bnka>-banka. " fallback
      lv_estado = <fs_bnka>-PROVZ.
      lv_cidade = <fs_bnka>-ort01.
    ENDIF.

*---------------------------------------------------------------------*
* Ajustes
*---------------------------------------------------------------------*

    IF lv_nome IS INITIAL.
      lv_nome = 'AGENCIA'.
    ENDIF.

    lv_dig = ''. " não existe no SAP

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      lv_codban && ';' && " CODBAN
      lv_codage && ';' && " CODAGE
      lv_nome   && ';' && " NOMAGE
      lv_estado && ';' && " CODEST
      lv_cidade && ';' && " CODCID (precisa conversão IBGE)
      lv_dig.             " DIGAGE

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo 1008 gerado:', gv_filename.

ENDFORM.
