#!/bin/bash

# 対象年
year=`date '+%Y' --date '1 month ago'`;

# 対象月
month=`date '+%m' --date '1 month ago'`;

# 作業ディレクトリ
dir=`dirname $0`/;

# パスの存在チェック
if [ ! -e ${dir} ]; then
    echo "${dir} が見つかりません";
    exit 1;
fi

# 通貨ペア
array=("USDJPY" "EURJPY" "GBPJPY" "AUDJPY" "NZDJPY" "CADJPY" "CHFJPY" "TRYJPY" "ZARJPY" "EURUSD" "GBPUSD" "AUDUSD" "NZDUSD" "EURGBP" "EURAUD" "GBPAUD" "EURCHF" "GBPCHF" "USDCHF");

# 通貨ペアでループ
for pair in ${array[@]}; do
    month=$(printf "%02d" ${month});
    file=${pair}_${year}${month}.csv;
    if [ ! -f ${dir}${file} ]; then
        echo "${dir}${file} が見つかりません";
        continue;
    fi

    # OHLC
    open=0;
    high=0;
    low=0;
    close=0;

    # 日時は初期値 (init) とする
    datetime="init";

    # 行を取得
    while read row; do
        # ヘッダ行は無視して処理開始
        if [ "${datetime}" = "init" ]; then
            datetime="start";
            continue;
        fi

        # 列を取得
        column1=`echo ${row} | cut -d , -f 1`;
        column2=`echo ${row} | cut -d , -f 2`;
        column3=`echo ${row} | cut -d , -f 3`;
        column4=`echo ${row} | cut -d , -f 4`;
        column5=`echo ${row} | cut -d , -f 5`;

        # 5分足に変換
        # 2019/12/21 18:00:00 を 2019-12-21 18:00:00 に置き換える
        # 00,01,02,03,04 を 00 分に、05,06,07,08,09 分を 05 分に丸める
        column1=${column1////-};
        column1=${column1:0:14}$(printf "%02d" `expr ${column1:14:2} - ${column1:14:2} % 5`)${column1:16:3};

        # 開始時の日時を記憶
        # 次の5分足に到達したら sql ファイルに書き出す
        if [ "${datetime}" = "start" ]; then
            datetime=${column1};
        elif [ "${datetime}" != "${column1}" ]; then
            echo "INSERT INTO tbl_candle VALUES ('${datetime}','${pair:0:3}_${pair:3:3}','${open}','${high}','${low}','${close}');" >> ${dir}${pair}.sql;

            # 次行のためにリセット
            datetime=${column1};
            open=0;
            high=0;
            low=0;
            close=0;
        fi

        # 始値 0 なら記憶
        result=`echo "${open} == 0" | bc`;
        if [ ${result} -eq 1 ]; then
            open=${column2};
        fi

        # 高値は一番数値が大きいところを記憶
        result=`echo "${high} == 0 || ${high} < ${column3}" | bc`;
        if [ ${result} -eq 1 ]; then
            high=${column3};
        fi

        # 安値は一番数値が小さいところを記憶
        result=`echo "${low} == 0 || ${low} > ${column4}" | bc`;
        if [ ${result} -eq 1 ]; then
            low=${column4};
        fi

        # 終値はファイルに書き出すまで上書きし続ける
        close=${column5};
    done < ${dir}${file}

    # 最終行を sql ファイルに書き出す
    echo "INSERT INTO tbl_candle VALUES ('${datetime}','${pair:0:3}_${pair:3:3}','${open}','${high}','${low}','${close}');" >> ${dir}${pair}.sql;
done
