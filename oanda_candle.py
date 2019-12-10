import json
import time
from datetime import datetime, timedelta
from decimal import Decimal
from pytz import timezone
from oandapyV20 import API
from oandapyV20.exceptions import V20Error
import oandapyV20.endpoints.instruments as instruments
import pandas as pd
import pymysql.cursors
import requests


# ---------- Settings ----------

# OANDA Personal Access Token
access_token = "## Your Personal Access Token ##"

# Environment (practice / live)
environment = "practice"

# Currency pair
instrument_list = [
    "USD_JPY", "EUR_JPY", "GBP_JPY", "AUD_JPY", "NZD_JPY",
    "CAD_JPY", "CHF_JPY", "TRY_JPY", "ZAR_JPY",
    "EUR_USD", "GBP_USD", "AUD_USD", "NZD_USD", "EUR_GBP",
    "EUR_AUD", "GBP_AUD", "EUR_CHF", "GBP_CHF", "USD_CHF"
]

# Start time (Before 5 min)
minutes = 5
delta = timedelta(minutes=minutes)

# Parameters
# granularity price
# ----------- ------
# S1: 1sec    B: Bid
# M1: 1min    A: Ask
# H1: 1hour
# D : day
# W : Week
# M : Month
params = {
    "from": "",
    "count": 1,
    "granularity": "M" + str(minutes),
    "price": "B"
}

# MySQL settings
host="localhost"
user="fxpi"
password="## fxpi's password ##"
db="fx"
charset="utf8mb4"

# LINE Notify settings
line_url = "https://notify-api.line.me/api/notify"
line_access_token = "## Your LINE Access Token ##"
line_headers = {'Authorization': 'Bearer ' + line_access_token}


# ----- Main routine -----

api = API(access_token=access_token, environment=environment)

def request_data():

    data = []
    line_message = ""
    for instrument in instrument_list:
        instruments_candles = instruments.InstrumentsCandles(instrument=instrument, params=params)

        try:
            api.request(instruments_candles)
            response = instruments_candles.response

            # Print raw data
            # print(json.dumps(response, indent=4))

            price = "bid" if params["price"] == "B" else "ask"
            for raw in response["candles"]:
                data.append([
                    raw["time"],
                    response["instrument"],
                    raw[price]["o"],
                    raw[price]["h"],
                    raw[price]["l"],
                    raw[price]["c"]
                ])

                # Difference high and low
                diff = Decimal(raw[price]["h"]) - Decimal(raw[price]["l"])
                print("{} {}: {}".format(
                    raw["time"].replace("000Z", "").replace("T", " "),
                    response["instrument"],
                    diff
                ))

                if response["instrument"].find("_JPY") > -1:
                    if diff >= 0.1:
                        line_message += "'" + response["instrument"] + "' "
                else:
                    if diff >= 0.0015:
                        line_message += "'" + response["instrument"] + "' "

            # DB connection
            conn = pymysql.connect(
                host=host,
                user=user,
                password=password,
                db=db,
                charset=charset,
                cursorclass=pymysql.cursors.DictCursor
            )

            # Insert DB
            try:
                for raw in response["candles"]:
                    with conn.cursor() as cursor:
                        sql  = "INSERT INTO tbl_candle (time, instrument, open, high, low, close) "
                        sql += "VALUES(%s, %s, %s, %s, %s, %s)"

                        cursor.execute(sql, (
                            raw["time"].replace("000Z", "").replace("T", " "),
                            response["instrument"],
                            raw[price]["o"],
                            raw[price]["h"],
                            raw[price]["l"],
                            raw[price]["c"]
                        ))
                    conn.commit()
            finally:
                conn.close()

            # Wait 1 sec
            time.sleep(1)

        except V20Error as e:
            print("Error: {}".format(e))

    # LINE Notify
    if len(line_message) > 0:
        line_payload = {"message": "There were signficant price fluctuations in " + line_message + "."}
        r = requests.post(line_url, headers=line_headers, params=line_payload)

    # Print formatted data
    data_len = len(data)
    if data_len == 0:
        data.append([" ", "", "", "", "", ""])
    df = pd.DataFrame(data)
    df.columns = ["time", "instrument", "open", "high", "low", "close"]
    df = df.set_index("time")
    if data_len > 0:
        df.index = pd.to_datetime(df.index)
    print(df)
    print("row(s) count: {}".format(data_len))

# Entry point
while 1:

    # Current time
    now = datetime.now(timezone("UTC"))

    # Run if current minute is a multiple of 'minutes'
    if now.minute % minutes == 0 and now.second == 0:
        now -= delta
        params["from"] = now.strftime("%Y-%m-%dT%H:%M:00.000000Z")

        # Request to OANDA
        request_data()

    # Wait 1 sec
    time.sleep(1)
