REPORT zhr_export_senior_1013.

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

  gv_filename = p_serv && sy-datum && '_SENIOR_1013.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;FICREG;CODPAI;CODEST;CODCID;CODBAI;ENDCEP;TIPLGR;'
           && 'ENDRUA;ENDNUM;ENDCPL;PAINAS;ESTNAS;CCINAS;NUMCID;EMICID;CIDEMI;ESTCID;DEXCID;'
           && 'ZONELE;SECELE;NUMELE;NUMCNH;CATCNH;VENCNH;ORGCNH;ESTCNH;NUMRES;CATRES;'
           && 'DESPRF;DATEXP;DATVEN;REGCON;DURCON;PROCON;EMAPAR;EMACOM;NOMCOM;'
           && 'DDITEL;DDDTEL;NUMTEL;NMDDI2;NMDDD2;NMTEL2;NOMSOC;PRICNH;DATCNH;CARSUS'.

*---------------------------------------------------------------------*
* Seleção base
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p2~cname,
    p2~gbdep,
    p2~gbort
  INTO TABLE @DATA(gt_emp)
  FROM pa0001 AS p1
  LEFT JOIN pa0002 AS p2
    ON p2~pernr = p1~pernr
   AND p2~begda <= @sy-datum
   AND p2~endda >= @sy-datum
  WHERE p1~begda <= @sy-datum
    AND p1~endda >= @sy-datum.

  IF sy-subrc <> 0.
    MESSAGE 'Nenhum dado encontrado na seleção base.' TYPE 'E'.
  ENDIF.

*---------------------------------------------------------------------*
* Endereço / Telefone
*---------------------------------------------------------------------*

  SELECT
    pernr,
    land1,
    state,
    ort01,
    ort02,
    pstlz,
    anssa,
    stras,
    hsnmr,
    locat,
    num01,
    num02
  INTO TABLE @DATA(gt_0006)
  FROM pa0006
  WHERE begda <= @sy-datum
    AND endda >= @sy-datum.

*---------------------------------------------------------------------*
* Email
*---------------------------------------------------------------------*

  SELECT
    pernr,
    subty,
    usrid_long
  INTO TABLE @DATA(gt_0105)
  FROM pa0105
  WHERE begda <= @sy-datum
    AND endda >= @sy-datum
    AND subty IN ('0010','0020').

*---------------------------------------------------------------------*
* Identidade
*---------------------------------------------------------------------*

  SELECT
    pernr,
    ident_nr,
    ident_org,
    es_emis,
    dt_emis
  INTO TABLE @DATA(gt_0465_0002)
  FROM pa0465
  WHERE subty = '0002'.

*---------------------------------------------------------------------*
* Título de Eleitor
*---------------------------------------------------------------------*

  SELECT
    pernr,
    elec_zone,
    elec_sect,
    elec_nr
  INTO TABLE @DATA(gt_0465_0005)
  FROM pa0465
  WHERE subty = '0005'.

*---------------------------------------------------------------------*
* CNH
*---------------------------------------------------------------------*

  SELECT
    pernr,
    drive_nr,
    drive_cat,
    "cnhorg,
    es_emis,
    dt_emis
    ""zzdt_hab
  INTO TABLE @DATA(gt_0465_0010)
  FROM pa0465
  WHERE subty = '0010'.

*---------------------------------------------------------------------*
* Reservista
*---------------------------------------------------------------------*

  SELECT
    pernr,
    mil_nr,
    mil_cat
  INTO TABLE @DATA(gt_0465_0007)
  FROM pa0465
  WHERE subty = '0007'.

*---------------------------------------------------------------------*
* Conselho Profissional
*---------------------------------------------------------------------*

  SELECT
    pernr,
    creg_nr
  INTO TABLE @DATA(gt_0465_0004)
  FROM pa0465
  WHERE subty = '0004'.

*---------------------------------------------------------------------*
* Estrangeiro / Registro contrato / prorrogações
*---------------------------------------------------------------------*

  SELECT
    pernr,
    ctedt
  INTO TABLE @DATA(gt_0016)
  FROM pa0016
  WHERE begda <= @sy-datum
    AND endda >= @sy-datum.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir o arquivo.' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

*---------------------------------------------------------------------*
* Loop principal
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1.

  DATA:
    lv_codpai TYPE string,
    lv_codest TYPE string,
    lv_codcid TYPE string,
    lv_codbai TYPE string,
    lv_endcep TYPE string,
    lv_tiplgr TYPE string,
    lv_endrua TYPE string,
    lv_endnum TYPE string,
    lv_endcpl TYPE string.

  DATA:
    lv_painas TYPE string,
    lv_estnas TYPE string,
    lv_ccinas TYPE string.

  DATA:
    lv_numcid TYPE string,
    lv_emicid TYPE string,
    lv_cidemi TYPE string,
    lv_estcid TYPE string,
    lv_dexcid TYPE char10.

  DATA:
    lv_zonele TYPE string,
    lv_secele TYPE string,
    lv_numele TYPE string.

  DATA:
    lv_numcnh TYPE string,
    lv_catcnh TYPE string,
    lv_vencnh TYPE char10,
    lv_orgcnh TYPE string,
    lv_estcnh TYPE string,
    lv_pricnh TYPE char10.

  DATA:
    lv_numres TYPE string,
    lv_catres TYPE string.

  DATA:
    lv_desprf TYPE string,
    lv_datexp TYPE char10,
    lv_datven TYPE char10,
    lv_regcon TYPE string,
    lv_durcon TYPE string,
    lv_procon TYPE string.

  DATA:
    lv_emapar TYPE string,
    lv_emacom TYPE string,
    lv_nomcom TYPE string.

  DATA:
    lv_dditel TYPE string,
    lv_dddtel TYPE string,
    lv_numtel TYPE string,
    lv_nmddi2 TYPE string,
    lv_nmddd2 TYPE string,
    lv_nmtel2 TYPE string.

  DATA:
    lv_nomsoc TYPE string,
    lv_datcnh TYPE char10,
    lv_carsus TYPE string.

  LOOP AT gt_emp ASSIGNING FIELD-SYMBOL(<fs_emp>).

    CLEAR:
      lv_tipcol,
      lv_codpai, lv_codest, lv_codcid, lv_codbai, lv_endcep, lv_tiplgr, lv_endrua, lv_endnum, lv_endcpl,
      lv_painas, lv_estnas, lv_ccinas,
      lv_numcid, lv_emicid, lv_cidemi, lv_estcid, lv_dexcid,
      lv_zonele, lv_secele, lv_numele,
      lv_numcnh, lv_catcnh, lv_vencnh, lv_orgcnh, lv_estcnh, lv_pricnh,
      lv_numres, lv_catres,
      lv_desprf, lv_datexp, lv_datven, lv_regcon, lv_durcon, lv_procon,
      lv_emapar, lv_emacom, lv_nomcom,
      lv_dditel, lv_dddtel, lv_numtel, lv_nmddi2, lv_nmddd2, lv_nmtel2,
      lv_nomsoc, lv_datcnh, lv_carsus.

*---------------------------------------------------------------------*
* TIPCOL
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_emp>-persg
      CHANGING lv_tipcol.

*---------------------------------------------------------------------*
* Endereço / Telefone
*---------------------------------------------------------------------*

    READ TABLE gt_0006 ASSIGNING FIELD-SYMBOL(<fs_0006>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.

      lv_codpai = <fs_0006>-land1.  " CODPAI
      lv_codest = <fs_0006>-state.  " CODEST
      lv_codcid = <fs_0006>-ort01.  " CODCID
      lv_codbai = <fs_0006>-ort02.  " CODBAI
      lv_endcep = <fs_0006>-pstlz.  " ENDCEP
      lv_tiplgr = <fs_0006>-anssa.  " TIPLGR
      lv_endrua = <fs_0006>-stras.  " ENDRUA
      lv_endnum = <fs_0006>-hsnmr.  " ENDNUM
      lv_endcpl = <fs_0006>-locat.  " ENDCPL

      PERFORM f_remove_special IN PROGRAM zhr_export_senior
        USING lv_endcep
        CHANGING lv_endcep.

      PERFORM f_split_phone
        USING <fs_0006>-num01
        CHANGING lv_dditel lv_dddtel lv_numtel.

      PERFORM f_split_phone
        USING <fs_0006>-num02
        CHANGING lv_nmddi2 lv_nmddd2 lv_nmtel2.

    ENDIF.

*---------------------------------------------------------------------*
* Dados nascimento
*---------------------------------------------------------------------*

    lv_painas = <fs_emp>-gbdep.  " PAINAS
    lv_ccinas = <fs_emp>-gbort.  " CCINAS

*---------------------------------------------------------------------*
* RG
*---------------------------------------------------------------------*

    READ TABLE gt_0465_0002 ASSIGNING FIELD-SYMBOL(<fs_rg>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.

      lv_numcid = <fs_rg>-ident_nr.   " NUMCID
      lv_emicid = <fs_rg>-ident_org.  " EMICID
      lv_estcid = <fs_rg>-es_emis.    " ESTCID

      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_rg>-dt_emis
        CHANGING lv_dexcid.

    ENDIF.

*---------------------------------------------------------------------*
* Título eleitor
*---------------------------------------------------------------------*

    READ TABLE gt_0465_0005 ASSIGNING FIELD-SYMBOL(<fs_ele>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.
      lv_zonele = <fs_ele>-elec_zone.
      lv_secele = <fs_ele>-elec_sect.
      lv_numele = <fs_ele>-elec_nr.
    ENDIF.

*---------------------------------------------------------------------*
* CNH
*---------------------------------------------------------------------*

    READ TABLE gt_0465_0010 ASSIGNING FIELD-SYMBOL(<fs_cnh>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.

      lv_numcnh = <fs_cnh>-drive_nr.
      lv_catcnh = <fs_cnh>-drive_cat.
*      lv_orgcnh = <fs_cnh>-cnhorg.
      lv_estcnh = <fs_cnh>-es_emis.

      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_cnh>-dt_emis
        CHANGING lv_vencnh.

*      PERFORM f_conv_date IN PROGRAM zhr_export_senior
*        USING <fs_cnh>-zzdt_hab
*        CHANGING lv_pricnh.

      lv_datcnh = lv_vencnh.

    ENDIF.

*---------------------------------------------------------------------*
* Reservista
*---------------------------------------------------------------------*

    READ TABLE gt_0465_0007 ASSIGNING FIELD-SYMBOL(<fs_res>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.
      lv_numres = <fs_res>-mil_nr.
      lv_catres = <fs_res>-mil_cat.
    ENDIF.

*---------------------------------------------------------------------*
* Conselho profissional
*---------------------------------------------------------------------*

    READ TABLE gt_0465_0004 ASSIGNING FIELD-SYMBOL(<fs_prof>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.
      lv_regcon = <fs_prof>-creg_nr.
    ENDIF.

*---------------------------------------------------------------------*
* Contrato
*---------------------------------------------------------------------*

    READ TABLE gt_0016 ASSIGNING FIELD-SYMBOL(<fs_0016>)
      WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.
      lv_durcon = <fs_0016>-ctedt.
    ENDIF.

*---------------------------------------------------------------------*
* Email
*---------------------------------------------------------------------*

    READ TABLE gt_0105 ASSIGNING FIELD-SYMBOL(<fs_mail_par>)
      WITH KEY pernr = <fs_emp>-pernr
               subty = '0010'.

    IF sy-subrc = 0.
      lv_emapar = <fs_mail_par>-usrid_long.
    ENDIF.

    READ TABLE gt_0105 ASSIGNING FIELD-SYMBOL(<fs_mail_com>)
      WITH KEY pernr = <fs_emp>-pernr
               subty = '0020'.

    IF sy-subrc = 0.
      lv_emacom = <fs_mail_com>-usrid_long.
    ENDIF.

*---------------------------------------------------------------------*
* Nome completo
*---------------------------------------------------------------------*

    lv_nomcom = <fs_emp>-cname.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_emp>-bukrs && ';' && " NUMEMP
      lv_tipcol     && ';' && " TIPCOL
      <fs_emp>-pernr && ';' && " NUMCAD
      ''            && ';' && " FICREG
      lv_codpai     && ';' && " CODPAI
      lv_codest     && ';' && " CODEST
      lv_codcid     && ';' && " CODCID
      lv_codbai     && ';' && " CODBAI
      lv_endcep     && ';' && " ENDCEP
      lv_tiplgr     && ';' && " TIPLGR
      lv_endrua     && ';' && " ENDRUA
      lv_endnum     && ';' && " ENDNUM
      lv_endcpl     && ';' && " ENDCPL
      lv_painas     && ';' && " PAINAS
      lv_estnas     && ';' && " ESTNAS
      lv_ccinas     && ';' && " CCINAS
      lv_numcid     && ';' && " NUMCID
      lv_emicid     && ';' && " EMICID
      lv_cidemi     && ';' && " CIDEMI
      lv_estcid     && ';' && " ESTCID
      lv_dexcid     && ';' && " DEXCID
      lv_zonele     && ';' && " ZONELE
      lv_secele     && ';' && " SECELE
      lv_numele     && ';' && " NUMELE
      lv_numcnh     && ';' && " NUMCNH
      lv_catcnh     && ';' && " CATCNH
      lv_vencnh     && ';' && " VENCNH
      lv_orgcnh     && ';' && " ORGCNH
      lv_estcnh     && ';' && " ESTCNH
      lv_numres     && ';' && " NUMRES
      lv_catres     && ';' && " CATRES
      lv_desprf     && ';' && " DESPRF
      lv_datexp     && ';' && " DATEXP
      lv_datven     && ';' && " DATVEN
      lv_regcon     && ';' && " REGCON
      lv_durcon     && ';' && " DURCON
      lv_procon     && ';' && " PROCON
      lv_emapar     && ';' && " EMAPAR
      lv_emacom     && ';' && " EMACOM
      lv_nomcom     && ';' && " NOMCOM
      lv_dditel     && ';' && " DDITEL
      lv_dddtel     && ';' && " DDDTEL
      lv_numtel     && ';' && " NUMTEL
      lv_nmddi2     && ';' && " NMDDI2
      lv_nmddd2     && ';' && " NMDDD2
      lv_nmtel2     && ';' && " NMTEL2
      lv_nomsoc     && ';' && " NOMSOC
      lv_pricnh     && ';' && " PRICNH
      lv_datcnh     && ';' && " DATCNH
      lv_carsus.                " CARSUS

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.

*---------------------------------------------------------------------*
FORM f_split_phone
  USING    p_phone
  CHANGING p_ddi
           p_ddd
           p_num.

  DATA lv_phone TYPE string.
  DATA lv_len   TYPE i.

  CLEAR: p_ddi, p_ddd, p_num.

  lv_phone = p_phone.

  REPLACE ALL OCCURRENCES OF '(' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF ')' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '-' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF ' ' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '/' IN lv_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '.' IN lv_phone WITH ''.
  CONDENSE lv_phone NO-GAPS.

  lv_len = strlen( lv_phone ).

  IF lv_len >= 10.
    p_ddd = lv_phone+0(2).
    p_num = lv_phone+2.
  ELSEIF lv_len > 2.
    p_ddd = lv_phone+0(2).
    p_num = lv_phone+2.
  ELSE.
    p_num = lv_phone.
  ENDIF.

ENDFORM.
