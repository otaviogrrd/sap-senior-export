REPORT ZHR_SENIOR_EXP_1010.


  PARAMETERS: p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

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

  gv_filename = p_serv && sy-datum && '_SENIOR_1010.csv'.

  gv_header = 'TABORG;CODLOC;LOCPAI;NOMLOC;DATCRI;DATEXT'.

*---------------------------------------------------------------------*
* Seleção OM (Locais)
*---------------------------------------------------------------------*

  SELECT
    orgeh,
    orgtx,
    begda,
    endda
  INTO TABLE @DATA(gt_org)
  FROM t527x
  WHERE endda >= @sy-datum.

*---------------------------------------------------------------------*
* Buscar relacionamento pai (HRP1001)
*---------------------------------------------------------------------*

  SELECT
    objid,     " filho
    sobid      " pai
  INTO TABLE @DATA(gt_rel)
  FROM hrp1001
  WHERE plvar = '01'
    AND otype = 'O'
    AND rsign = 'B'
    AND relat = '002'   " pertence a
    AND endda >= @sy-datum.

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
    lv_datcri TYPE char10,
    lv_datext TYPE char10,
    lv_pai    TYPE string.

  LOOP AT gt_org ASSIGNING FIELD-SYMBOL(<fs_org>).

*---------------------------------------------------------------------*
* Data
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_org>-begda
      CHANGING lv_datcri.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_org>-endda
      CHANGING lv_datext.

*---------------------------------------------------------------------*
* Buscar pai
*---------------------------------------------------------------------*

    CLEAR lv_pai.

    READ TABLE gt_rel ASSIGNING FIELD-SYMBOL(<fs_rel>)
      WITH KEY objid = <fs_org>-orgeh.

    IF sy-subrc = 0.
      lv_pai = <fs_rel>-sobid.
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      '1'                    && ';' && " TABORG (fixo)
      <fs_org>-orgeh         && ';' && " CODLOC
      lv_pai                 && ';' && " LOCPAI
      <fs_org>-orgtx         && ';' && " NOMLOC
      lv_datcri              && ';' && " DATCRI
      lv_datext.                         " DATEXT

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
