# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.apps import AppConfig

class configservercsfConfig(AppConfig):
    name = 'configservercsf'

    def ready(self):
        import signals
