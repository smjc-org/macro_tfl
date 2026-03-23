/*
 * Macro Name:    reg_pb
 * Macro Purpose: Passing-Bablok 回归
 * Author:        wtwang
 * Version Date:  2026-03-23
*/

%macro reg_pb(indata, outdata, x, y, alpha = 0.05, debug = false) / parmbuff;
    /*  indata:  数据集名称
     *  outdata: 保存回归分析结果的数据集名称
     *  x:       x 轴变量
     *  y:       y 轴变量
     *  alpha:   双侧显著性水平，默认为 0.05
     *  debug:   调试模式
    */

    /*统一参数大小写*/
    %let indata  = %sysfunc(strip(%superq(indata)));
    %let outdata = %sysfunc(strip(%superq(outdata)));
    %let x       = %upcase(%sysfunc(strip(%bquote(&x))));
    %let y       = %upcase(%sysfunc(strip(%bquote(&y))));
    %let alpha   = %sysfunc(strip(%bquote(&alpha)));
    %let debug   = %upcase(%sysfunc(strip(%bquote(&debug))));

    /*复制 indata*/
    data tmp_indata;
        set %superq(indata) end = end;
        _seq = _n_;
        if end then call symputx("n", _n_);
    run;

    /*点和点进行配对*/
    proc sql noprint;
        create table tmp_indata_paired as
            select
                p1._seq as p1_seq label = "第一个点的序号",
                p1.&x   as p1_x   label = "第一个点的 x 值",
                p1.&y   as p1_y   label = "第一个点的 y 值",
                p2._seq as p2_seq label = "第二个点的序号",
                p2.&x   as p2_x   label = "第二个点的 x 值",
                p2.&y   as p2_y   label = "第二个点的 y 值",
                ifc(p1_x = p2_x and p1_y = p2_y, "Y", "") as flag_overlap label = "标识变量-重合的点",
                ifc(p1_x = p2_x and p1_y < p2_y, "Y", "") as flag_neg_inf label = "标识变量-负无穷大",
                ifc(p1_x = p2_x and p1_y > p2_y, "Y", "") as flag_pos_inf label = "标识变量-正无穷大",
                ifn(calculated flag_overlap ^= "Y" and
                    calculated flag_pos_inf ^= "Y" and
                    calculated flag_neg_inf ^= "Y", (p2_y - p1_y)/(p2_x - p1_x), .)
                                                          as slope label = "斜率",
                ifc(not missing(calculated slope) and calculated slope = -1, "Y", "")
                                                          as flag_slope_eq_minus_one label = "标识变量-斜率等于负一",
                (case when calculated flag_neg_inf = "Y" then 1
                      when calculated flag_pos_inf = "Y" then 3
                      else 2
                end)                                      as flag_sort               label = "标识变量-排列顺序"
            from tmp_indata as p1, tmp_indata as p2
            where (p1_seq < p2_seq) and calculated flag_overlap ^= "Y" and calculated flag_slope_eq_minus_one ^= "Y"
            order by flag_sort, slope;

        /*计算对子数*/
        select count(*) into :M trimmed from tmp_indata_paired;

        /*记录对子在序列中的位置*/
        alter table tmp_indata_paired add seq num(8);
        update tmp_indata_paired set seq = monotonic();
    quit;

    /*计算斜率小于 -1 的点对数*/
    proc sql noprint;
        select sum((not missing(slope) and slope < -1) or flag_neg_inf = "Y") into :K trimmed from tmp_indata_paired;
    quit;

    /*创建存储参数估计值的数据集*/
    proc sql noprint;
        create table tmp_parameter_estimate
            (param char(20), name char(20), estimate num(8), lower num(8), upper num(8));
    quit;

    /*点估计-斜率*/
    proc sql noprint;
        insert into tmp_parameter_estimate
            set param = "斜率", name = "slope", estimate = (case when mod(&M, 2) = 1 then (select slope from tmp_indata_paired where seq = (&M + 1)/2 + &K)
                                                                 when mod(&M, 2) = 0 then ((select slope from tmp_indata_paired where seq = (&M/2 + &K)) +
                                                                                           (select slope from tmp_indata_paired where seq = (&M/2 + 1 + &K))) / 2
                                                            end);
    quit;

    /*点估计-截距*/
    proc sql noprint;
        create table tmp_indata_intercept_est as
            select
                &x,
                &y,
                &y - (select estimate from tmp_parameter_estimate where name = "slope") * &x as intercept_individual
            from tmp_indata;
        insert into tmp_parameter_estimate
            set param = "截距", name = "intercept", estimate = (select median(intercept_individual) from tmp_indata_intercept_est);
    quit;

    /*区间估计-斜率*/
    data _null_;
        C = probit(1 - &alpha / 2) * sqrt(&n * (&n - 1) * (2 * &n + 5) / 18);
        M1 = round((&M - C) / 2);
        M2 = &M - M1 + 1;
        call symputx("M1", M1);
        call symputx("M2", M2);
    run;
    proc sql noprint;
        update tmp_parameter_estimate
            set lower = (select slope from tmp_indata_paired where seq = &M1 + &K),
                upper = (select slope from tmp_indata_paired where seq = &M2 + &K)
            where name = "slope";
    quit;

    /*区间估计-截距*/
    proc sql noprint;
        create table tmp_indata_intercept_ci_est as
            select
                &x,
                &y,
                &y - (select upper from tmp_parameter_estimate where name = "slope") * &x as intercept_lower_individual,
                &y - (select lower from tmp_parameter_estimate where name = "slope") * &x as intercept_upper_individual
            from tmp_indata;
        update tmp_parameter_estimate
            set lower = (select median(intercept_lower_individual) from tmp_indata_intercept_ci_est),
                upper = (select median(intercept_upper_individual) from tmp_indata_intercept_ci_est)
            where name = "intercept";
    quit;

    /*输出数据集*/
    data &outdata;
        set tmp_parameter_estimate;
    run;

    /*删除中间数据集*/
    %if %bquote(&debug) = %upcase(false) %then %do;
        proc datasets library = work nowarn noprint;
            delete tmp_indata
                   tmp_indata_paired
                   tmp_parameter_estimate
                   tmp_indata_intercept_est
                   tmp_indata_intercept_ci_est
                   ;
        quit;
    %end;

    %exit:
    %put NOTE: 宏程序 reg_pb 已结束运行！;
%mend;

%reg_pb(indata = adeff, outdata = pb_res, x = crcd1, y = trcd1, debug = true);
