# Gloomhaven Monster Recognizer

App to make setting the game up easier. It is used to recognize and find monsters from the pile.

## Model

The app is based on a coputer vision segmentation model. It is using a pretrained YOLOv11 segmentation model. The dataset of Gloomhaven monsters contains 1500 images for the base game 47 classes. The codebase contains all the code for labeling the dataset in YOLO compatible style. It also implements a simple python matplotlib oriented tool for creating label masks using the Meta's SAM2 model.

## App

The app is writen in flutter framework. It is a very simple interface for the model writen to alow easy cross platform deployment.