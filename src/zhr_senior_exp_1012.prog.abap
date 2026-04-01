REPORT zhr_senior_exp_1012.

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

  gv_filename = sy-datum && '_SENIOR_1012.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;NOMFUN;APEFUN;DATADM;TIPCON;'
  && 'TIPSEX;ESTCIV;GRAINS;DATNAS;'
  && 'CODNAC;ANOCHE;VISEST;REGEST;DVLEST;DVLCTP;NUMCTP;'
  && 'SERCTP;ESTCTP;DEXCTP;NUMCPF;NUMPIS;DCDPIS;'
  && 'PAGSIN;MODPAG;CODBAN;CODAGE;CONBAN;DIGBAN;TIPAPO;'
  && 'DATAPO;OUTCON;OUTTET;DEFFIS;RACCOR;CODDEF;'
  && 'CATSEF;MOVSEF;BENREA;DOCEST;TPCTBA;APOIDA;DATCHE;'
  && 'RECADI;REC13S;LISRAI;EMICAR;CONRHO;PERPAG;'
  && 'TIPOPC;DATOPC;CONFGT;DIGCAR;TPCPIX;CHVPIX;COTDEF;'
  && 'SITPRO;EMPRESA;FILIAL'.

*---------------------------------------------------------------------*
* Sele??o de colaboradores
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~btrtl,
    p1~persg,
    p2~cname,
    p2~rufnm,
    p2~gesch,
    p2~famst,
    p2~gbdat,
    p2~natio,
    p4~sbart,
    p9~zlsch,
    p9~bankl,
    p9~bankn,
    p9~bankp,
    p625~race,
    p398~empid,
    p398~escol,
    p398~fgtso,
    p398~fgtsd,
    p0~stat2

INTO TABLE @DATA(gt_emp)

FROM pa0001 AS p1

LEFT JOIN pa0000 AS p0
  ON p0~pernr = p1~pernr
 AND p0~begda <= @sy-datum
 AND p0~endda >= @sy-datum

LEFT JOIN pa0002 AS p2
  ON p2~pernr = p1~pernr
 AND p2~begda <= @sy-datum
 AND p2~endda >= @sy-datum

LEFT JOIN pa0004 AS p4
  ON p4~pernr = p1~pernr
 AND p4~begda <= @sy-datum
 AND p4~endda >= @sy-datum

LEFT JOIN pa0009 AS p9
  ON p9~pernr = p1~pernr
 AND p9~begda <= @sy-datum
 AND p9~endda >= @sy-datum

LEFT JOIN pa0625 AS p625
  ON p625~pernr = p1~pernr
 AND p625~begda <= @sy-datum
 AND p625~endda >= @sy-datum

LEFT JOIN pa0398 AS p398
  ON p398~pernr = p1~pernr
 AND p398~begda <= @sy-datum
 AND p398~endda >= @sy-datum

WHERE p1~begda <= @sy-datum
  AND p1~endda >= @sy-datum.

*---------------------------------------------------------------------*
* Data admiss?o
*---------------------------------------------------------------------*

  SELECT
    pernr,
    dar01,
    dat01
   INTO TABLE @DATA(gt_0041)
   FROM pa0041
  WHERE endda = '99991231'
    AND dar01 = '01'.

*---------------------------------------------------------------------*
* CPF / PIS
*---------------------------------------------------------------------*

  SELECT
    pernr,
    cpf_nr
  INTO TABLE @DATA(gt_0465_1)
  FROM pa0465
  WHERE subty = '0001'.

  SELECT
    pernr,
    pis_nr,
    dt_emis
  INTO TABLE @DATA(gt_0465_6)
  FROM pa0465
  WHERE subty = '0006'.

  SELECT
    pernr,
    es_emis ,
    ctps_nr   ,
    ctps_serie,
    dt_emis
  INTO TABLE @DATA(gt_0465_3)
  FROM pa0465
  WHERE subty = '0003'.

  SELECT
    pernr,
    dt_arrv,
    dt_emis
  INTO TABLE @DATA(gt_0465_9)
  FROM pa0465
  WHERE subty = '0009'.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop colaboradores
*---------------------------------------------------------------------*

  DATA:
    lv_datadm TYPE char10,
    lv_datnas TYPE char10,
    lv_dcdpis TYPE char10,
    lv_dexctp TYPE char10,
    lv_datopc TYPE char10,
    lv_docest TYPE char2,
    lv_tipopc TYPE c LENGTH 1,
    lv_raccor TYPE c LENGTH 1,
    lv_tipcol TYPE c LENGTH 1,
    lv_sexo   TYPE c LENGTH 1,
    lv_estciv TYPE c LENGTH 1,
    lv_tipcon TYPE c LENGTH 2.
  DATA:
    lv_codban TYPE string,
    lv_codage TYPE string,
    lv_conban TYPE string,
    lv_digban TYPE string,
    lv_sitpro TYPE string.

  LOOP AT gt_emp ASSIGNING FIELD-SYMBOL(<fs_emp>).


    READ TABLE gt_0041 ASSIGNING FIELD-SYMBOL(<fs_0041>)
    WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.
      IF <fs_0041>-dar01 = '01'.
        PERFORM f_conv_date IN PROGRAM zhr_export_senior
          USING <fs_0041>-dat01
          CHANGING lv_datadm.
      ENDIF.
    ENDIF.

*---------------------------------------------------------------------*
* CPF
*---------------------------------------------------------------------*

    DATA(lv_numcpf) = ||.

    READ TABLE gt_0465_1 ASSIGNING FIELD-SYMBOL(<fs_cpf>)
    WITH KEY pernr = <fs_emp>-pernr.

    IF sy-subrc = 0.
      lv_numcpf = <fs_cpf>-cpf_nr.
    ENDIF.

*---------------------------------------------------------------------*
* carteira
*---------------------------------------------------------------------*

    DATA(lv_numctp) = ||.
    DATA(lv_serctp) = ||.
    DATA(lv_estctp) = ||.

    READ TABLE gt_0465_3 ASSIGNING FIELD-SYMBOL(<fs_carteira>)
      WITH KEY pernr = <fs_emp>-pernr.
    IF sy-subrc = 0.
      lv_numctp = <fs_carteira>-ctps_nr.
      lv_serctp = <fs_carteira>-ctps_serie.
      lv_estctp = <fs_carteira>-es_emis.

      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_carteira>-dt_emis
        CHANGING lv_dexctp.
    ENDIF.

*---------------------------------------------------------------------*
* PIS
*---------------------------------------------------------------------*

    DATA(lv_numpis) = ||.

    READ TABLE gt_0465_6 ASSIGNING FIELD-SYMBOL(<fs_pis>)
    WITH KEY pernr = <fs_emp>-pernr.
    IF sy-subrc = 0.
      lv_numpis = <fs_pis>-pis_nr.
      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_pis>-dt_emis
        CHANGING lv_dcdpis.
    ENDIF.


*---------------------------------------------------------------------*
* carteira
*---------------------------------------------------------------------*

    DATA(lv_anoche) = ||.
    DATA(lv_datche) = ||.

    READ TABLE gt_0465_9 ASSIGNING FIELD-SYMBOL(<fs_estrang>)
      WITH KEY pernr = <fs_emp>-pernr.
    IF sy-subrc = 0.
      lv_anoche = <fs_estrang>-dt_arrv(4).

      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_estrang>-dt_arrv
        CHANGING lv_datche.
    ENDIF.
*---------------------------------------------------------------------*
* Banco / Ag?ncia / Conta
*---------------------------------------------------------------------*

    CLEAR: lv_codban, lv_codage, lv_conban, lv_digban.
    IF <fs_emp>-bankl IS NOT INITIAL.

      lv_codban = <fs_emp>-bankl(3).     " CODBAN
      lv_codage = <fs_emp>-bankl+3.      " CODAGE

    ENDIF.

    IF <fs_emp>-bankn IS NOT INITIAL.

      DATA(lv_len) = strlen( <fs_emp>-bankn )  - 1 .

      IF lv_len > 1.

        lv_conban = <fs_emp>-bankn(lv_len).      " CONBAN
        lv_digban = <fs_emp>-bankn+lv_len(1).      " DIGBAN

      ELSE.

        lv_conban = <fs_emp>-bankn.

      ENDIF.

    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcon IN PROGRAM zhr_export_senior
      USING <fs_emp>-gbdat
      CHANGING lv_datnas.
    PERFORM f_conv_tipcon IN PROGRAM zhr_export_senior
      USING <fs_emp>-empid
      CHANGING lv_tipcon.
    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_emp>-persg
      CHANGING lv_tipcol.
    PERFORM f_conv_tipsex IN PROGRAM zhr_export_senior
      USING <fs_emp>-gesch
      CHANGING lv_sexo.
    PERFORM f_conv_estciv IN PROGRAM zhr_export_senior
      USING <fs_emp>-famst
      CHANGING lv_estciv.
    PERFORM f_conv_raccor IN PROGRAM zhr_export_senior
      USING <fs_emp>-race
      CHANGING lv_raccor.

    "FGts
    PERFORM f_conv_simnao IN PROGRAM zhr_export_senior
      USING <fs_emp>-fgtso
      CHANGING lv_tipopc.
    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_emp>-fgtsd
      CHANGING lv_datopc.


    DATA(lv_deffis) = ''.
    IF <fs_emp>-sbart IS INITIAL.
      lv_deffis = 'N'.
    ELSE.
      lv_deffis = 'S'.
    ENDIF.

    DATA(lv_numemp) = ||.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_emp>-bukrs
      CHANGING lv_numemp.

    CASE <fs_emp>-stat2.
      WHEN '0'.
        lv_sitpro = 'Demitido'.
      WHEN '3'.
        lv_sitpro = 'Ativo'.
      WHEN OTHERS.
        lv_sitpro = 'Afastado'.
    ENDCASE.

    gv_line =
      lv_numemp           && ';' && " NUMEMP
      lv_tipcol           && ';' && " TIPCOL
      <fs_emp>-pernr      && ';' && " NUMCAD
      <fs_emp>-cname      && ';' && " NOMFUN
      <fs_emp>-rufnm      && ';' && " APEFUN
      lv_datadm           && ';' && " DATADM
      lv_tipcon           && ';' && " TIPCON
      lv_sexo             && ';' && " TIPSEX
      lv_estciv           && ';' && " ESTCIV
      <fs_emp>-escol      && ';' && " GRAINS
      lv_datnas           && ';' && " DATNAS
      <fs_emp>-natio      && ';' && " CODNAC
      lv_anoche           && ';' && " ANOCHE
      ''                  && ';' && " VISEST
      ''                  && ';' && " REGEST
      ''                  && ';' && " DVLEST
      ''                  && ';' && " DVLCTP
      lv_numctp           && ';' && " NUMCTP
      lv_serctp           && ';' && " SERCTP
      lv_estctp           && ';' && " ESTCTP
      lv_dexctp           && ';' && " DEXCTP
      lv_numcpf           && ';' && " NUMCPF
      lv_numpis           && ';' && " NUMPIS
      lv_dcdpis           && ';' && " DCDPIS
      'S'                 && ';' && " PAGSIN
      <fs_emp>-zlsch      && ';' && " MODPAG
      lv_codban           && ';' && " CODBAN
      lv_codage           && ';' && " CODAGE
      lv_conban           && ';' && " CONBAN
      lv_digban           && ';' && " DIGBAN
      ''                  && ';' && " TIPAPO
      ''                  && ';' && " DATAPO
      'U'                 && ';' && " OUTCON
      'N'                 && ';' && " OUTTET
      lv_deffis           && ';' && " DEFFIS
      lv_raccor           && ';' && " RACCOR
      <fs_emp>-sbart      && ';' && " CODDEF
      ''                  && ';' && " CATSEF
      ''                  && ';' && " MOVSEF
      'N'                 && ';' && " BENREA
      ''                  && ';' && " DOCEST
      ''                  && ';' && " TPCTBA
      'N'                 && ';' && " APOIDA
      lv_datche           && ';' && " DATCHE
      'S'                 && ';' && " RECADI
      'S'                 && ';' && " REC13S
      'S'                 && ';' && " LISRAI
      'N'                 && ';' && " EMICAR
      '2'                 && ';' && " CONRHO
      'M'                 && ';' && " PERPAG
      lv_tipopc           && ';' && " TIPOPC
      lv_datopc           && ';' && " DATOPC
      ''                  && ';' && " CONFGT
      ''                  && ';' && " DIGCAR
      ''                  && ';' && " TPCPIX
      ''                  && ';' && " CHVPIX
      'N'                 && ';' && " COTDEF
      lv_sitpro           && ';' && " SITPRO
      <fs_emp>-bukrs      && ';' && " EMPRESA
      <fs_emp>-btrtl.               " FILIAL


    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
