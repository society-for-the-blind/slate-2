from django.urls import path

from . import views

app_name = "lynx"

urlpatterns = [

    # path('add-contact/', views.IntakeFormView.as_view(), name='add_intake1'),
    path('add-contact/', views.add_contact, name='add_contact'),
    path('add-intake/<int:contact_id>/', views.add_intake, name='add_intake'),
    path('add-contact-information/<int:contact_id>/', views.add_contact_information, name='add_contact_information'),
    path('clients', views.ContactListView.as_view(), name='contact_list'),
    path('client/<int:pk>', views.ContactDetailView.as_view(), name='contact_detail'),
    path('add-emergency/<int:contact_id>', views.add_emergency, name='add_emergency'),
    path('add-address/<int:contact_id>', views.add_address, name='add_address'),
    path('add-email/<int:contact_id>', views.add_email, name='add_email'),
    path('add-phone/<int:contact_id>', views.add_phone, name='add_phone'),
    path('', views.index, name='index'),
]