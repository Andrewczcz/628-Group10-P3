# start with list_inputs, finished with outputs
# require file:
#    onehot_encoder_model.pkl
#    scaler.pkl
#    model.py
#    simple_model_epoch_1001.pth
#---bellow are code for copy---
import pandas as pd
import numpy as np
from sklearn.neural_network import MLPRegressor
from sklearn.preprocessing import OneHotEncoder
import joblib

list_inputs = pd.read_csv('delay_time_sample_data.csv')
X_test = pd.DataFrame(list_inputs)

onehot_encoder_loaded = joblib.load('onehot_encoder_model.pkl')
scaler = joblib.load('scaler.pkl')
model = joblib.load('new_new_model_1.pkl')

for col in ['ORIGIN_DATE', 'ORIGIN_DATE_CST', 'DEST_DATE', 'DEST_DATE_CST']:
    X_test[col] = pd.to_datetime(X_test[col], errors='coerce')   
X_test['ORIGIN_Hour'] = X_test['ORIGIN_DATE'].dt.hour
X_test['ORIGIN_Minute'] = X_test['ORIGIN_DATE'].dt.minute
X_test['ORIGIN_CST_Hour'] = X_test['ORIGIN_DATE_CST'].dt.hour
X_test['ORIGIN_CST_Minute'] = X_test['ORIGIN_DATE_CST'].dt.minute

X_test['DEST_Hour'] = X_test['DEST_DATE'].dt.hour
X_test['DEST_Minute'] = X_test['DEST_DATE'].dt.minute
X_test['DEST_CST_Hour'] = X_test['DEST_DATE_CST'].dt.hour
X_test['DEST_CST_Minute'] = X_test['DEST_DATE_CST'].dt.minute

enc_feature = ['DAY_OF_WEEK', 'DEST', 'ORIGIN', 'MKT_CARRIER', 'OP_CARRIER']
X_encoder = onehot_encoder_loaded.transform(X_test[enc_feature])
X_encoder = pd.DataFrame.sparse.from_spmatrix(
   X_encoder, 
    columns=onehot_encoder_loaded.get_feature_names_out(enc_feature)  
)
X_test = X_test.reset_index(drop=True)
X_encoder = X_encoder.reset_index(drop=True)
X_test = X_test.drop(enc_feature, axis=1)
X_test = pd.concat([X_test, X_encoder], axis=1)

X_test = X_test.drop(['ORIGIN_DATE', 'DEST_DATE', 'DEST_DATE_CST','ORIGIN_DATE_CST'], axis=1)

def encode_month_columns(X_test):
    if 'MONTH' not in X_test.columns:
        raise ValueError("The DataFrame does not contain a 'MONTH' column.")
    month_dummies = pd.get_dummies(X_test['MONTH'], prefix='MONTH')
    required_columns = ['MONTH_1', 'MONTH_11', 'MONTH_12']
    for col in required_columns:
        if col not in month_dummies.columns:
            month_dummies[col] = 0
    month_dummies = month_dummies[required_columns]
    X_test = X_test.drop('MONTH', axis=1).join(month_dummies)
    
    return X_test
X_test = encode_month_columns(X_test)

X_test = X_test.drop(['CRS_DEP_TIME','CRS_ARR_TIME','YEAR'], axis=1)
X_test = X_test.astype({col: 'int' for col in X_test.select_dtypes('bool').columns})

feature = list(X_test.columns)
X_test = scaler.transform(X_test)
X_test = pd.DataFrame(X_test, columns=feature)

outputs = model.predict(X_test)