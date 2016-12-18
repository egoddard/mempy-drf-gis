.. role:: bash(code)
   :language: bash

===============================================
Django Rest Framework GIS - Mempy December 2016
===============================================

This is the repo for a talk about Django Rest Framework - GIS given at the
December 2016 MemPy meetup. The talk is an introduction to GeoDjango,
Django REST Framework and the Django REST Framework - GIS extension. A
Vagrantfile is included that will install all of dependencies required for the
demo project in an Ubuntu 16.04 VM.

At the end of the demo you'll have a working API that serves GeoJSON amenities
(schools, police stations, fire stations, libraries, etc.) in the Memphis area
that were extracted from OpenStreetMap. The API could be used for a web map or
to load data into desktop GIS software such as QGIS.

Start the VM
------------

Clone the repository and start the vagrant VM:: 

    git clone https://github.com/egoddard/mempy-drf-gis.git
    cd mempy-drf-gis
    vagrant up

When the machine is finished building, login with::

    vagrant ssh
    
Once in the ssh session, cd into the shared /vagrant directory with::

    cd /vagrant

Create a PostGIS database
-------------------------

The PostGIS extension has to be created as an administrator, so enable it
outside of the migrations framework::

    # Create a database named osm (osm stands for Open Street Map) 
    # using the postgres user
    createdb -U postgres osm

    # Pass a sql command to the OSM database to enable PostGIS.
    psql -U postgres osm -c "CREATE EXTENSION postgis;"

The VM has been configured to allow any local user to connect as any database
user without a password. Obviously, don't do this in production.

Create a Django application and apply initial migrations
--------------------------------------------------------

Create a new virtual environment (using Python3) for the Django project. Use
pip to install Django and then use django-admin to start a new project.::

    mkvirtualenv -p python3 django-gis
    pip install django psycopg2
    django-admin startproject gis . # Dont forget the trailing dot!

Apply the initial Django migration by running:::

    python manage.py migrate

Run the server and make sure everything works:::

    # specify 0.0.0.0:8000 so your host browser can see the server on the VM
    python manage.py runserver 0.0.0.0:8000

Visit http://localhost:8000 in your browser and you should see the default
Django "It Worked!" page. Use CTRL+C to stop the server.

Install and Configure Django REST Framework
-------------------------------------------

Now we're ready to configure the Django REST Framework (DRF). Use pip to install
it and the DRF-GIS addon. We'll also go ahead and install django-filter, which
we will use towards the end:::

    pip install djangorestframework djangorestframework-gis django-filter

In gis/settings.py, update the DATABASE and INSTALLED_APPS sections to use
GeoDjango and DRF:::

    DATABASES = {
        'default': {
             'ENGINE': 'django.contrib.gis.db.backends.postgis',
             'NAME': 'osm',
             'USER': 'postgres',
        },
    }

    # And then add django.contrib.gis, rest_framework, and rest_framework_gis
    # to INSTALLED_APPS:
    INSTALLED_APPS = [
        'django.contrib.admin',
        'django.contrib.auth',
        'django.contrib.contenttypes',
        'django.contrib.sessions',
        'django.contrib.messages',
        'django.contrib.staticfiles',
        'django.contrib.gis',
        'rest_framework',
        'rest_framework_gis',
    ]


Create an app and a model
----------------------------

With GeoDjango and DRF working, we're ready to create an app and setup a model.
Create an app with:::
    python manage.py startapp osm
    
Since our api will serve data from OpenStreetMap, we name our app osm.

Add the osm app to the end of INSTALLED_APPS in gis/settings.py:::

    INSTALLED_APPS = [
        'django.contrib.admin',
        'django.contrib.auth',
        # ...,
        'django.contrib.gis',
        'rest_framework',
        'rest_framework_gis',
        'osm',
    ]
        
In osm/models.py, We'll replace the models import statement with the Geodjango
version. Then we'll create a new model named Amenity and add fields for
osm_id, name, type, and geometry.::

    # in osm/models.py:
    from django.contrib.gis.db import models

    class Amenity(models.Model):
        osm_id = models.BigIntegerField()
        name = models.TextField(blank=True)
        amenity_type = models.CharField(max_length=30)
        geometry = models.PointField(srid=4326)
        
Create a new migration for our amenity model, and apply it.::

    python manage.py makemigrations osm
    python manage.py migrate

Load fixtures into the Amenities model
--------------------------------------

We need to load the data extracted from OpenStreetMap into our database. To
preload data in Django, you use a fixtures file. While django can be configured
to automatically load fixtures from certain directories, we can also use the
loaddata command and the path to a json or YAML file to load the data:::

    python manage.py loaddata osm_amenities.json

Create a serializer
-------------------

With our model and data defined, we can start working on the DRF setup. The 
first step is to create a serializer. A serializer tells Django how to export
a model's data to json.

In osm, create a new serializers.py file. Since we are handling spatial data,
we are going to to use the rest_framework_gis GeoFeatureModelSerializer, which
subclasses from the rest_framework.serializer.ModelSerializer class.::

    # osm/serializers.py
    from rest_framework_gis.serializers import GeoFeatureModelSerializer
    from .models import Amenity

    class AmenitySerializer(GeoFeatureModelSerializer):
        class Meta:
            model = Amenity
            geo_field = "geometry"
            fields = ('id', 'osm_id', 'name', 'amenity_type',)

For a basic implementation, we just need to tell the serializer which model to
use and the name of the field containing the spatial geometry.

Create a View and configure URLS
--------------------------------

With our serializer defined, we're ready to create an endpoint to view and
request the data. in osm/views.py, create the following:::

    # osm/views.py
    from rest_framework import viewsets
    from .models import Amenity
    from .serializers import AmenitySerializer

    class AmenityViewSet(viewsets.ReadOnlyModelViewSet):

        queryset = Amenity.objects.all()
        serializer_class = AmenitySerializer

Finally, we need to configure the URLs so that the API endpoints are reachable.
Modify gis/urls.py, so that it looks like the following:::

    # gis/urls.py
    from django.conf.urls import url, include
    from django.contrib import admin
    from rest_framework import routers
    from osm import views

    router = routers.DefaultRouter()
    router.register('amenities', views.AmenityViewSet)

    urlpatterns = [
        url(r'^', include(router.urls)),
        url(r'^admin/', admin.site.urls),
    ]

With the model, serializer, view and url configured, we're able to view the
browseable API. Run the server with::

    python manage.py runserver 0.0.0.0:8000
    
and check out the API.

Filtering API results
---------------------

While we have a nice API, it would be better if we could filter based on location
and attributes. For that we can use the DRF-GIS InBBoxFilter (Bounding Box Filter)
and django-filter for filtering on attribute values. Adding filters is easy,
requiring only a few additions to views.py:::

    # osm/views.py
    from rest_framework import viewsets
    from django_filters.rest_framework import DjangoFilterBackend # NEW
    from rest_framework_gis.filters import InBBoxFilter #NEW
    from .models import Amenity
    from .serializers import AmenitySerializer

    class AmenityViewSet(viewsets.ReadOnlyModelViewSet):
        # Configure the bbox filter, filter backends, and fields to filter on
        bbox_filter_field = 'geometry'
        bbox_filter_include_overlapping = True
        filter_backends = (DjangoFilterBackend, InBBoxFilter,)
        filter_fields = ('name', 'amenity_type')

        # change all objects to filter()
        queryset = Amenity.objects.filter()
        serializer_class = AmenitySerializer

With the filters configured we can pass query parameters to our API to select
only those points within a certain area, with a specific name, or with a certain
amenity type. For example:
http://localhost:8000/amenities/?in_bbox=-90.09,35.01,-89.80,35.18&amenity_type=hospital
returns only points that are of type hospital within the coordinates passed to
in_bbox.

Further learning
----------------

GeoDjango has a tutorial at
https://docs.djangoproject.com/en/1.10/ref/contrib/gis/tutorial/. 

Django REST Framework has a very detailed tutorial that will make a lot of the
things covered here much clearer. It is at
http://www.django-rest-framework.org/tutorial/quickstart/.

Django REST Framework - GIS doesn't have a tutorial, but has decent
documentation on Github
(https://github.com/djangonauts/django-rest-framework-gis). 

