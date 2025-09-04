<?php
/*
###############################################################################
# Copyright (C) 2006-2025 Jonathan Michaelson
#
# https://github.com/waytotheweb/scripts
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses>.
###############################################################################
*/

class Ctrl_Nodeworx_Configservercsf extends Ctrl_Nodeworx_Plugin
{

    protected function _init()
    {
        chmod('/usr/local/interworx/plugins/configservercsf', 0711);
        chmod('/usr/local/interworx/plugins/configservercsf/lib', 0711);
        chmod('/usr/local/interworx/plugins/configservercsf/lib/index.pl', 0711);
        chmod('/usr/local/interworx/plugins/configservercsf/lib/reseller.pl', 0711);
	}

    public function launchAction()
    {
        $this->getView()->assign('title', 'Configservercsf Services');
        $this->getView()->assign('template', 'admin');
    }

    public function indexAction()
    {
        if (IW::NW()->isReseller()) {
	        $this->_getPlugin()->runReseller();
		} else {
	        $this->_getPlugin()->runAdmin();
		}
        exit;
    }
}
