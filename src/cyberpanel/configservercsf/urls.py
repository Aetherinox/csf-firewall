from django.urls import path
from . import views

urlpatterns = [
    path('', views.configservercsf, name='configservercsf'),
    path('iframe/', views.configservercsfiframe, name='configservercsfiframe'),
]
