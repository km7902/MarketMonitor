#!/bin/bash

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
    file=${pair}.sql;
    if [ ! -f ${dir}${file} ]; then
        echo "${dir}${file} が見つかりません";
        continue;
    fi

    # テーブルに投入
    mysql -u fxpi -praspberry fx < ${dir}${file};

    # ファイル行数を確認
    wc -l ${dir}${file};

    # テーブル行数を確認
    head=`head -1 ${dir}${file} | cut -c 33-51`;
    tail=`tail -1 ${dir}${file} | cut -c 33-51`;
    mysql -u fxpi -praspberry fx -e "SELECT COUNT(*) FROM tbl_candle WHERE time >= '${head}' AND time <= '${tail}' AND instrument = '${pair:0:3}_${pair:3:3}'";
done
