<?php
/*
    @app                ConfigServer Security & Firewall (CSF)
                        Login Failure Daemon (LFD)
    @website            https://configserver.dev
    @docs               https://docs.configserver.dev
    @download           https://download.configserver.dev
    @repo               https://github.com/Aetherinox/csf-firewall
    @copyright          Copyright (C) 2025-2026 Aetherinox
                        Copyright (C) 2006-2025 Jonathan Michaelson
                        Copyright (C) 2006-2025 Way to the Web Ltd.
    @license            GPLv3
    @updated            02.27.2026
    
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or (at
    your option) any later version.
    
    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, see <https://www.gnu.org/licenses>.
*/

class Plugin_Configservercsf extends Plugin
{

    public function preAction($ctrl_act, Ctrl_Abstract $Ctrl, $action, $params)
    {
        if ($ctrl_act === 'Ctrl_Nodeworx_Firewall:index') {
            throw new IWorx_Exception_ActionBlocked('ConfigServer Plugins > Security & Firewall, has replaced this item');
        }
		elseif (strpos($ctrl_act, 'Ctrl_Nodeworx_Firewall') === 0) {
			throw new IWorx_Exception_ActionBlocked('N/A');
		}
    }

	public function getCategory()
    {
        return Plugin_Category::ADVANCED;
    }

    public function getPriority()
    {
        return 40;
    }

    public function runReseller()
    {
        $env = array('IWORX_SESSION_ID' => session_id());
        session_write_close();

        $InterWorx   = IW::Env()->getActiveSession()->getInterWorx();
        $WorkingUser = $InterWorx->getWorkingUser();
        $env['REMOTE_USER'] = $WorkingUser->getNickname();

        $this->_runPage('reseller', $env);
    }

    public function runAdmin()
    {
        $env = array('IWORX_SESSION_ID' => session_id());
        session_write_close();

        $this->_runPage('index', $env);
    }

    /**
     * Runs a CSF page script as root and prints its CGI response.
     *
     * Uses the InterWorx CsfPage escalation when this InterWorx has it, and
     * falls back to runasuser on older releases.
     */
    private function _runPage($page, array $env)
    {
        $env['QUERY_STRING']   = http_build_query($_GET);
        $env['REQUEST_METHOD'] = $_SERVER['REQUEST_METHOD'];

        $env['REMOTE_ADDR']     = $_SERVER['REMOTE_ADDR'];
        $env['HTTP_USER_AGENT'] = $_SERVER['HTTP_USER_AGENT'];

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $env['CONTENT_LENGTH']     = $_SERVER['CONTENT_LENGTH'];
            $env['POST']               = http_build_query($_POST);
            $env['HTTP_RAW_POST_DATA'] = http_build_query($_POST);
        }

        if (class_exists('IWorx\\Process\\IWorx\\CsfPage')) {
            $Page = \IWorx\Process\IWorx\CsfPage::factory();
            $Page->setPage($page);
            $Page->setEnvVariables($env);
            $Page->exec();
            $result = $Page->getOutput();
            if ($Page->getRetval() === \IWorx\Process\IWorx\ProcessRunAsUser::RETVAL_RECONSTRUCTION_REJECTED) {
                header('Content-Type: text/plain');
                print implode("\n", $result) . "\n";
                return;
            }
        } else {
            foreach ($env as $name => $value) {
                putenv($name . '=' . $value);
            }
            $cmd = Ini::get(Ini::IWORX_BIN, 'runasuser');
            $cmd .= " root custom /usr/local/interworx/plugins/configservercsf/lib/{$page}.pl 2>&1";
            IWorxExec::exec($cmd, $result, $retval, IWorxExec::STDERR_2_STDOUT);
        }

        $header = 1;
        foreach ($result as $line) {
            if ($header) {
                header ("$line\n");
            } else {
                print "$line\n";
            }
            if ($header && $line == "") {
                $header = 0;
            }
        }
    }

    public function updateNodeworxMenu(IWorxMenuManager $MenuMan)
    {
        $new_data = array( 'text' => 'ConfigServer Plugins',
                       'class' => 'iw-i-plugin',
                       'disabled_for_reseller' => '0' );

        $MenuMan->addMenuItemAfter(
            'iw-menu-svc',
            'menu-configserver',
            $new_data
        );

		$new_data = array( 'text' => 'Security & Firewall',
                       'url' => '/nodeworx/configservercsf?action=launch',
                       'parent' => 'menu-configserver',
                       'class' => 'iw-i-plugin',
                       'disabled_for_reseller' => '0' );

        $MenuMan->addMenuItemAfter(
            'menu-configserver',
            'menu-configservercsf',
            $new_data
        );
    }

}
