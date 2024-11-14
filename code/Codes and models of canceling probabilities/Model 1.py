import pandas as pd
from sklearn.model_selection import train_test_split
import numpy as np
from imblearn.over_sampling import RandomOverSampler
from imblearn.under_sampling import RandomUnderSampler
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score, accuracy_score

d = pd.read_csv('data.csv')
X = d.drop(columns=['CANCELLED'])
y = d['CANCELLED']

# Split data into an 8:2 ratio for training and test sets (model2)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1, random_state=44)

# One-Hot Encoding on the unbalanced training set (model2)
X_train_encoded = pd.get_dummies(X_train[['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST']], sparse=True)
X_train_sparse = X_train.drop(columns=['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST'])
X_train_combined = pd.concat([X_train_sparse, X_train_encoded], axis=1)
X_train_converted = X_train_combined.astype(pd.SparseDtype("float", fill_value=0))

# One-Hot Encoding on the test set
X_test_encoded = pd.get_dummies(X_test[['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST']], sparse=True)
X_test_sparse = X_test.drop(columns=['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST'])
X_test_combined = pd.concat([X_test_sparse, X_test_encoded], axis=1)
X_test_converted = X_test_combined.astype(pd.SparseDtype("float", fill_value=0))
X_test_converted = X_test_converted.reindex(columns=X_train_converted.columns, fill_value=0)

# Train logistic regression model for model2
model2 = LogisticRegression(solver='saga', max_iter=5000, fit_intercept=False)
model2.fit(X_train_converted, y_train)

y_test_pred = model2.predict(X_test_converted)
f1_test_model2 = f1_score(y_test, y_test_pred)
print(f"F1 score on test set (model2): {f1_test_model2:.4f}")

positive_indices = (y_test == 1)
negative_indices = (y_test == 0)
positive_accuracy_model2 = accuracy_score(y_test[positive_indices], y_test_pred[positive_indices])
print(f"Accuracy for positive samples on test set (model2): {positive_accuracy_model2:.4f}")
negative_accuracy_model2 = accuracy_score(y_test[negative_indices], y_test_pred[negative_indices])
print(f"Accuracy for negative samples on test set (model2): {negative_accuracy_model2:.4f}")

# Initialize oversampler and undersampler
over_sampler = RandomOverSampler(sampling_strategy=0.5, random_state=44)  # Increase positive samples to half of negative samples
under_sampler = RandomUnderSampler(sampling_strategy=1.0, random_state=44)  # Balance classes with equal positive and negative samples

# Apply oversampling on the training set to increase positive samples to half of negative samples
X_train_oversampled, y_train_oversampled = over_sampler.fit_resample(X_train, y_train)

# Apply undersampling on the oversampled data to balance positive and negative samples
X_train_balanced, y_train_balanced = under_sampler.fit_resample(X_train_oversampled, y_train_oversampled)

print("Training set size after oversampling:", X_train_oversampled.shape)
print("Training set size after balancing:", X_train_balanced.shape)
print("Number of positive samples:", sum(y_train_balanced == 1))
print("Number of negative samples:", sum(y_train_balanced == 0))

# Extract unique values from ORIGIN and DEST columns in the full dataset
origin_airports = d['ORIGIN'].unique().tolist()
dest_airports = d['DEST'].unique().tolist()

# Convert ORIGIN and DEST values in the full dataset to sets
origin_airports_set = set(origin_airports)
dest_airports_set = set(dest_airports)

# Get the actual ORIGIN and DEST airports present in X_train_balanced
origin_in_X_train_balanced = set(X_train_balanced['ORIGIN'].unique())
dest_in_X_train_balanced = set(X_train_balanced['DEST'].unique())

# Find airports in the full dataset but missing in X_train_balanced
origin_not_in_X_train_balanced = origin_airports_set - origin_in_X_train_balanced
dest_not_in_X_train_balanced = dest_airports_set - dest_in_X_train_balanced
print("Airports in ORIGIN (full dataset) but not in X_train_balanced:", origin_not_in_X_train_balanced)
print("Airports in DEST (full dataset) but not in X_train_balanced:", dest_not_in_X_train_balanced)

# One-Hot Encoding on the balanced training set
X_train_encoded = pd.get_dummies(X_train_balanced[['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST']], sparse=True)
X_train_sparse = X_train_balanced.drop(columns=['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST'])
X_train_combined = pd.concat([X_train_sparse, X_train_encoded], axis=1)
X_train_converted = X_train_combined.astype(pd.SparseDtype("float", fill_value=0))

# One-Hot Encoding on the test set
X_test_encoded = pd.get_dummies(X_test[['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST']], sparse=True)
X_test_sparse = X_test.drop(columns=['DEP_CateTIME', 'ARR_CateTIME', 'OP_UNIQUE_CARRIER', 'ORIGIN', 'DEST'])
X_test_combined = pd.concat([X_test_sparse, X_test_encoded], axis=1)
X_test_converted = X_test_combined.astype(pd.SparseDtype("float", fill_value=0))
X_test_converted = X_test_converted.reindex(columns=X_train_converted.columns, fill_value=0)

model = LogisticRegression(solver='saga', max_iter=5000, fit_intercept=False)
model.fit(X_train_converted, y_train_balanced)

# Predict on the balanced training set and calculate F1 score (model)
y_train_pred = model.predict(X_train_converted)
f1_train = f1_score(y_train_balanced, y_train_pred)
print(f"F1 score on balanced training set (model): {f1_train:.4f}")

# Predict on the test set and calculate F1 score (model)
y_test_pred = model.predict(X_test_converted)
f1_test = f1_score(y_test, y_test_pred)
print(f"F1 score on test set (model): {f1_test:.4f}")

positive_indices = (y_test == 1)
negative_indices = (y_test == 0)

positive_accuracy = accuracy_score(y_test[positive_indices], y_test_pred[positive_indices])
print(f"Accuracy for positive samples on test set (model): {positive_accuracy:.4f}")
negative_accuracy = accuracy_score(y_test[negative_indices], y_test_pred[negative_indices])
print(f"Accuracy for negative samples on test set (model): {negative_accuracy:.4f}")

