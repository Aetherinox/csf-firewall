<!doctype html>
<html lang="en">
<head>
	<title>ConfigServer : Unauthorized Access</title>
	<meta charset="UTF-8">
	<script src="https://www.google.com/recaptcha/api.js" async defer></script>
	<link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
	<link rel="icon" href="data:;base64,iVBORw0KGgo=">
</head>
<body>
	<?php require( '../recaptcha.php' ); ?>
	<?php
		$lang = "en";
		if ( isset($_SERVER[ 'HTTP_ACCEPT_LANGUAGE' ] ) )
        {
			$lang = substr( $_SERVER[ 'HTTP_ACCEPT_LANGUAGE' ], 0, 2 );
		}

		if( file_exists( '../' . $lang . '.php' ) )
        {
			require( '../' . $lang . '.php' );
		}
        else
        {
			require( '../en.php' );
		}
	?>

<div class="container-fluid">
	<img src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiP
z4KPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJod
HRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjRweCIgaGVpZ2h0PSI2NHB4IiB2a
WV3Qm94PSIwIDAgNjQgNjQiIHZlcnNpb249IjEuMSI+CjxnIGlkPSJzdXJmYWNlMSI+CjxwYXRoI
HN0eWxlPSIgc3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOmV2ZW5vZGQ7ZmlsbDpyZ2IoMTAwJSwxMDAlL
DEwMCUpO2ZpbGwtb3BhY2l0eToxOyIgZD0iTSAxOS4xNDQ1MzEgMzguNjY0MDYyIEMgMTguNTA3O
DEyIDQwLjk3NjU2MiAxNy4zNzUgNDIuNzg1MTU2IDE0Ljg5MDYyNSA0NS40Mzc1IEMgMTMuNjk1M
zEyIDQ2LjcxODc1IDEzLjM5ODQzOCA0Ny4xMjEwOTQgMTIuODc1IDQ4LjE4NzUgQyAxMi41MzUxN
TYgNDguODc1IDEyLjE5MTQwNiA0OS43NDYwOTQgMTIuMTEzMjgxIDUwLjEyMTA5NCBDIDExLjkyO
TY4OCA1MC45OTIxODggMTIuMDM1MTU2IDUzLjEyNSAxMi4zMDA3ODEgNTMuODU5Mzc1IEMgMTIuN
TgyMDMxIDU0LjYzMjgxMiAxMi41NTg1OTQgNTQuOTg0Mzc1IDEyLjIxODc1IDU1LjExNzE4OCBDI
DExLjk3MjY1NiA1NS4yMTA5MzggMTIuMDYyNSA1NS4yODUxNTYgMTMgNTUuNzM4MjgxIEMgMTYuN
TExNzE5IDU3LjQzMzU5NCAyMiA1Ny40NzI2NTYgMjUuNTU4NTk0IDU1LjgyNDIxOSBDIDI2LjM1O
TM3NSA1NS40NTcwMzEgMjYuNTExNzE5IDU1LjMzOTg0NCAyNi40Mzc1IDU1LjE1NjI1IEMgMjYuM
zA4NTk0IDU0Ljg0NzY1NiAyNi4zMTI1IDU0LjgwODU5NCAyNi42MjUgNTMuNjI4OTA2IEMgMjYuO
DU5Mzc1IDUyLjc0MjE4OCAyNi44OTQ1MzEgNTIuMzYzMjgxIDI2LjgzOTg0NCA1MS4yNTM5MDYgQ
yAyNi43MzA0NjkgNDkuMDExNzE5IDI2LjIwMzEyNSA0Ny45MzM1OTQgMjQuMDQyOTY5IDQ1LjU1N
DY4OCBDIDIxLjY2MDE1NiA0Mi45Mjk2ODggMjAuODE2NDA2IDQxLjYwMTU2MiAyMC4wMTU2MjUgM
zkuMjEwOTM4IEMgMTkuNzQ2MDk0IDM4LjM5NDUzMSAxOS41IDM3LjcxMDkzOCAxOS40NzY1NjIgM
zcuNjgzNTk0IEMgMTkuNDQ5MjE5IDM3LjY2MDE1NiAxOS4zMDA3ODEgMzguMDk3NjU2IDE5LjE0N
DUzMSAzOC42NjQwNjIgIi8+CjxwYXRoIHN0eWxlPSIgc3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOmV2Z
W5vZGQ7ZmlsbDpyZ2IoODAuMDAwMDAxJSw3Ljg0MzEzOCUsNy44NDMxMzglKTtmaWxsLW9wYWNpd
Hk6MTsiIGQ9Ik0gMTUuMDU0Njg4IDUuMjYxNzE5IEMgMTUuMDA3ODEyIDUuMzM1OTM4IDE1LjA0M
jk2OSA2LjExMzI4MSAxNS4xMjg5MDYgNi45ODQzNzUgQyAxNS4zMzk4NDQgOS4xNDA2MjUgMTUuM
jMwNDY5IDEyLjYyODkwNiAxNC44ODY3MTkgMTQuNDU3MDMxIEMgMTQuMjA3MDMxIDE4LjA4OTg0N
CAxMi44NjMyODEgMjEuNTcwMzEyIDEwLjgzOTg0NCAyNC45Mzc1IEMgOS45MTQwNjIgMjYuNDgwN
DY5IDguOTkyMTg4IDI3Ljc2OTUzMSA3LjMzMjAzMSAyOS44NDM3NSBDIDUuODI4MTI1IDMxLjcyM
jY1NiA1LjA1MDc4MSAzMi45MzM1OTQgNC40NjA5MzggMzQuMzEyNSBDIDMuNTg1OTM4IDM2LjM2N
zE4OCAzLjI1IDM4LjEzMjgxMiAzLjI1IDQwLjY4MzU5NCBDIDMuMjUgNDQuODgyODEyIDQuNDcyN
jU2IDQ4LjIxODc1IDcuMTEzMjgxIDUxLjIzNDM3NSBDIDguNDcyNjU2IDUyLjc4MTI1IDExLjA0M
jk2OSA1NC44MzIwMzEgMTEuODkwNjI1IDU1LjA0Mjk2OSBDIDEyLjQ0MTQwNiA1NS4xNzU3ODEgM
TIuNTc4MTI1IDU0Ljg3NSAxMi4zMjQyMTkgNTQuMDg5ODQ0IEMgMTEuNzQyMTg4IDUyLjI5Njg3N
SAxMS44MDQ2ODggNTAuNSAxMi41MDc4MTIgNDguODEyNSBDIDEzLjAzOTA2MiA0Ny41MzUxNTYgM
TMuNDEwMTU2IDQ3LjAwMzkwNiAxNC44Nzg5MDYgNDUuMzk4NDM4IEMgMTYuNzMwNDY5IDQzLjM3N
SAxNy40Mjk2ODggNDIuNDU3MDMxIDE4LjA1MDc4MSA0MS4yNSBDIDE4LjU5NzY1NiA0MC4xODc1I
DE5LjE2NDA2MiAzOC42NTYyNSAxOS4zMjAzMTIgMzcuODIwMzEyIEMgMTkuMzY3MTg4IDM3LjU3N
DIxOSAxOS40Mzc1IDM3LjM3NSAxOS40ODQzNzUgMzcuMzc1IEMgMTkuNTI3MzQ0IDM3LjM3NSAxO
S42NTYyNSAzNy43NTc4MTIgMTkuNzY1NjI1IDM4LjIxODc1IEMgMjAuNDMzNTk0IDQwLjk4MDQ2O
SAyMS4zODI4MTIgNDIuNTA3ODEyIDI0LjgyMDMxMiA0Ni4zNzUgQyAyNS43Njk1MzEgNDcuNDQ1M
zEyIDI2LjQ1MzEyNSA0OC42Mjg5MDYgMjYuNzYxNzE5IDQ5Ljc1IEMgMjcuMDE5NTMxIDUwLjY5M
TQwNiAyNi45NTcwMzEgNTIuNjYwMTU2IDI2LjYzMjgxMiA1My44NDM3NSBDIDI2LjE5NTMxMiA1N
S40MjU3ODEgMjYuNDE3OTY5IDU1LjU5NzY1NiAyNy43NjE3MTkgNTQuNzM0Mzc1IEMgMzAuNTYyN
SA1Mi45Mjk2ODggMzIuNzg5MDYyIDUwLjUzMTI1IDM0LjExNzE4OCA0Ny44OTQ1MzEgQyAzNC42O
DM1OTQgNDYuNzY5NTMxIDM1LjMzMjAzMSA0NC43NTc4MTIgMzUuNTcwMzEyIDQzLjM3NSBDIDM1L
jgyMDMxMiA0MS45NDkyMTkgMzUuNzUzOTA2IDM5LjIxNDg0NCAzNS40Mzc1IDM3Ljc1IEMgMzQuN
zk2ODc1IDM0LjgwNDY4OCAzMy40ODQzNzUgMzIuMTE3MTg4IDMxLjUgMjkuNjg3NSBDIDI4LjE1M
jM0NCAyNS41ODU5MzggMjUuODI4MTI1IDE5Ljg3ODkwNiAyNS41MTk1MzEgMTUuMDExNzE5IEMgM
jUuNDUzMTI1IDEzLjk0OTIxOSAyNS4zOTQ1MzEgMTMuNjg3NSAyNS4yMTA5MzggMTMuNTc0MjE5I
EMgMjQuODgyODEyIDEzLjM3NSAyNC42OTE0MDYgMTMuNjk5MjE5IDI0LjUxNTYyNSAxNC43NTc4M
TIgQyAyNC40Mzc1IDE1LjI0MjE4OCAyMy45NzY1NjIgMTYuNjc5Njg4IDIzLjQ5NjA5NCAxNy45N
DkyMTkgQyAyMy4wMTU2MjUgMTkuMjE4NzUgMjIuNDkyMTg4IDIwLjcwMzEyNSAyMi4zMzU5MzggM
jEuMjQyMTg4IEwgMjIuMDUwNzgxIDIyLjIyNjU2MiBMIDIxLjcxNDg0NCAyMC40NDE0MDYgQyAyM
S4wNzgxMjUgMTcuMDU0Njg4IDE5LjcxNDg0NCAxMi44NjcxODggMTguMjU3ODEyIDkuODA4NTk0I
EMgMTcuNTE1NjI1IDguMjQ2MDk0IDE2LjExMzI4MSA1LjcyNjU2MiAxNS43NzczNDQgNS4zNDM3N
SBDIDE1LjU2MjUgNS4wOTc2NTYgMTUuMTgzNTk0IDUuMDU0Njg4IDE1LjA1NDY4OCA1LjI2MTcxO
SAiLz4KPHBhdGggc3R5bGU9IiBzdHJva2U6bm9uZTtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOnJnY
ig3MC4xOTYwOCUsNzAuMTk2MDglLDcwLjE5NjA4JSk7ZmlsbC1vcGFjaXR5OjE7IiBkPSJNIDMxL
jkyMTg3NSAyNC40Mzc1IEMgMzEuODI0MjE5IDI0LjY4MzU5NCAzMi4yNzM0MzggMjUuNDIxODc1I
DMzLjQzMzU5NCAyNi45Mzc1IEMgMzUuNjc5Njg4IDI5Ljg3NSAzNi4wMzEyNSAzMC4zNzUgMzYuN
jU2MjUgMzEuNTI3MzQ0IEwgMzcuMzEyNSAzMi43NDIxODggTCAzOS43MjI2NTYgMzIuNzQ2MDk0I
EMgNDIuNTc4MTI1IDMyLjc1IDQyLjg3NSAzMi42NzU3ODEgNDMuMjUgMzEuODQ3NjU2IEMgNDMuN
DY4NzUgMzEuMzcxMDk0IDQzLjQ5NjA5NCAzMS4wMTU2MjUgNDMuNDk2MDk0IDI4LjUyNzM0NCBDI
DQzLjUgMjUuNDgwNDY5IDQzLjQyNTc4MSAyNS4wNzAzMTIgNDIuNzczNDM4IDI0LjUzNTE1NiBDI
DQyLjQzNzUgMjQuMjYxNzE5IDQyLjQxNzk2OSAyNC4yNTc4MTIgMzcuMjE0ODQ0IDI0LjI1MzkwN
iBDIDMyLjcwMzEyNSAyNC4yNSAzMS45ODA0NjkgMjQuMjczNDM4IDMxLjkyMTg3NSAyNC40Mzc1I
E0gNDcuMjY5NTMxIDI0LjQ2MDkzOCBDIDQ2LjQ1MzEyNSAyNC44NjMyODEgNDYuNDM3NSAyNC45N
DkyMTkgNDYuNDM3NSAyOC41IEMgNDYuNDM3NSAzMi4wNjY0MDYgNDYuNDUzMTI1IDMyLjE0ODQzO
CA0Ny4yODkwNjIgMzIuNTQyOTY5IEMgNDcuNjc1NzgxIDMyLjcyNjU2MiA0OC40MDYyNSAzMi43N
SA1My43MDcwMzEgMzIuNzUgQyA1OS40ODQzNzUgMzIuNzUgNTkuNzAzMTI1IDMyLjc0MjE4OCA2M
C4xMDE1NjIgMzIuNDk2MDk0IEMgNjAuODA4NTk0IDMyLjA2NjQwNiA2MC44NzUgMzEuNzIyNjU2I
DYwLjg3NSAyOC41IEMgNjAuODc1IDI1LjI3NzM0NCA2MC44MDg1OTQgMjQuOTMzNTk0IDYwLjEwM
TU2MiAyNC41MDM5MDYgQyA1OS43MDMxMjUgMjQuMjU3ODEyIDU5LjQ4ODI4MSAyNC4yNSA1My42O
Dc1IDI0LjI1MzkwNiBDIDQ4LjM3NSAyNC4yNTM5MDYgNDcuNjQwNjI1IDI0LjI3NzM0NCA0Ny4yN
jk1MzEgMjQuNDYwOTM4IE0gMzguNDM3NSAzNS41IEMgMzguMzk0NTMxIDM1LjU3MDMxMiAzOC40O
DgyODEgMzYuMjAzMTI1IDM4LjY0NDUzMSAzNi45MDYyNSBDIDM4Ljg5MDYyNSAzOC4wMTE3MTkgM
zguOTI5Njg4IDM4LjU3ODEyNSAzOC45NDkyMTkgNDEuMDYyNSBMIDM4Ljk2ODc1IDQzLjkzNzUgT
CA0OS4zNDc2NTYgNDMuOTY4NzUgTCA1OS43MzA0NjkgNDQgTCA2MC4xMzI4MTIgNDMuNjY0MDYyI
EMgNjAuODI0MjE5IDQzLjA4MjAzMSA2MC44NzUgNDIuODA0Njg4IDYwLjg3NSAzOS42NjAxNTYgQ
yA2MC44NzUgMzYuNDEwMTU2IDYwLjgxNjQwNiAzNi4xNTIzNDQgNTkuOTM3NSAzNS42NjAxNTYgT
CA1OS40Mzc1IDM1LjM3ODkwNiBMIDQ4Ljk3NjU2MiAzNS4zNzg5MDYgQyA0Mi4xMjUgMzUuMzc1I
DM4LjQ4ODI4MSAzNS40MTc5NjkgMzguNDM3NSAzNS41IE0gMTUuNTU0Njg4IDQ0LjY1NjI1IEwgM
TUuMTg3NSA0NS4wNjI1IEwgMTUuNTkzNzUgNDQuNjk1MzEyIEMgMTUuODE2NDA2IDQ0LjQ5MjE4O
CAxNiA0NC4zMTI1IDE2IDQ0LjI4OTA2MiBDIDE2IDQ0LjE5MTQwNiAxNS44OTg0MzggNDQuMjc3M
zQ0IDE1LjU1NDY4OCA0NC42NTYyNSBNIDIzLjg3NSA0NS40MTQwNjIgQyAyMy44NzUgNDUuNDM3N
SAyNC4wNTg1OTQgNDUuNjE3MTg4IDI0LjI4MTI1IDQ1LjgyMDMxMiBMIDI0LjY4NzUgNDYuMTg3N
SBMIDI0LjMyMDMxMiA0NS43ODEyNSBDIDIzLjk3NjU2MiA0NS40MDIzNDQgMjMuODc1IDQ1LjMxN
jQwNiAyMy44NzUgNDUuNDE0MDYyIE0gMzguMjc3MzQ0IDQ2Ljc4MTI1IEMgMzguMjEwOTM4IDQ2L
jg2NzE4OCAzNy45MTQwNjIgNDcuNSAzNy42MjUgNDguMTg3NSBDIDM2LjcxODc1IDUwLjM0NzY1N
iAzNS40NzY1NjIgNTIuMzI4MTI1IDMzLjgzMjAzMSA1NC4yNDIxODggQyAzMy41MTE3MTkgNTQuN
jE3MTg4IDMzLjI1IDU1IDMzLjI1IDU1LjA5NzY1NiBDIDMzLjI1IDU1LjI0MjE4OCAzMy45ODA0N
jkgNTUuMjYxNzE5IDM3Ljc4MTI1IDU1LjIyNjU2MiBDIDQxLjg2NzE4OCA1NS4xOTE0MDYgNDIuM
zU5Mzc1IDU1LjE2NDA2MiA0Mi43NzM0MzggNTQuOTYwOTM4IEMgNDMuNTc0MjE5IDU0LjU1ODU5N
CA0My42MjUgNTQuMzE2NDA2IDQzLjYyNSA1MC43MjY1NjIgTCA0My42MjUgNDcuNTUwNzgxIEwgN
DMuMTUyMzQ0IDQ3LjA4NTkzOCBMIDQyLjY3NTc4MSA0Ni42MjUgTCA0MC41NDI5NjkgNDYuNjI1I
EMgMzguOTg0Mzc1IDQ2LjYyNSAzOC4zNzEwOTQgNDYuNjY3OTY5IDM4LjI3NzM0NCA0Ni43ODEyN
SBNIDQ3LjA4NTkzOCA0Ny4xMDE1NjIgTCA0Ni42MTMyODEgNDcuNTg1OTM4IEwgNDYuNjQ4NDM4I
DUwLjkwNjI1IEwgNDYuNjg3NSA1NC4yMzA0NjkgTCA0NyA1NC41NjY0MDYgQyA0Ny42NTIzNDQgN
TUuMjYxNzE5IDQ3LjUyNzM0NCA1NS4yNSA1My42NDg0MzggNTUuMjUgQyA1Ny4xNDg0MzggNTUuM
jUgNTkuNDg4MjgxIDU1LjE5OTIxOSA1OS43NzczNDQgNTUuMTIxMDk0IEMgNjAuMDMxMjUgNTUuM
DUwNzgxIDYwLjQxMDE1NiA1NC44MjAzMTIgNjAuNjIxMDk0IDU0LjYwOTM3NSBMIDYxIDU0LjIzM
DQ2OSBMIDYxIDUxLjAzOTA2MiBDIDYxIDQ4LjQ2NDg0NCA2MC45NjQ4NDQgNDcuNzczNDM4IDYwL
jgxMjUgNDcuNDU3MDMxIEMgNjAuNDM3NSA0Ni42NjQwNjIgNjAuNjcxODc1IDQ2LjY5MTQwNiA1M
y44MTI1IDQ2LjY1MjM0NCBMIDQ3LjU2MjUgNDYuNjEzMjgxIEwgNDcuMDg1OTM4IDQ3LjEwMTU2M
iBNIDExLjkxMDE1NiA1MS41NjI1IEMgMTEuOTEwMTU2IDUxLjkwNjI1IDExLjkzNzUgNTIuMDMxM
jUgMTEuOTY0ODQ0IDUxLjg0Mzc1IEMgMTEuOTkyMTg4IDUxLjY1MjM0NCAxMS45OTIxODggNTEuM
zcxMDk0IDExLjk2NDg0NCA1MS4yMTg3NSBDIDExLjkzMzU5NCA1MS4wNjI1IDExLjkxMDE1NiA1M
S4yMTg3NSAxMS45MTAxNTYgNTEuNTYyNSBNIDI2LjkxMDE1NiA1MS41NjI1IEMgMjYuOTEwMTU2I
DUxLjkwNjI1IDI2LjkzNzUgNTIuMDMxMjUgMjYuOTY0ODQ0IDUxLjg0Mzc1IEMgMjYuOTkyMTg4I
DUxLjY1MjM0NCAyNi45OTIxODggNTEuMzcxMDk0IDI2Ljk2NDg0NCA1MS4yMTg3NSBDIDI2LjkzM
zU5NCA1MS4wNjI1IDI2LjkxMDE1NiA1MS4yMTg3NSAyNi45MTAxNTYgNTEuNTYyNSAiLz4KPC9nP
go8L3N2Zz4K" />
	<div class="alert alert-warning">
        <h2><?php echo $lang[ 'warning' ]; ?></h2>
    </div>

	<p>
        <?php echo $lang[ 'contact' ]; ?>
    </p>

	<p>
        <?php echo $lang[ 'blocked ip' ]; ?> <b><?php echo $_SERVER[ 'REMOTE_ADDR' ] ?></b>
    </p>

	<p>
        <?php echo $lang[ 'hostname' ]; ?> <b><?php echo php_uname( 'n' ); ?></b>
    </p>

	<br />

	<p>
        <?php echo $lang[ 'recaptcha title' ]; ?>
    </p>

	<form action="" method="POST">
		<div class="row">
			<div class="col-md-4 col-md-offset-4">
				<div class="panel panel-default">
					<div class="panel-body">
						<div class="g-recaptcha" data-sitekey="<?php echo $sitekey; ?>"></div>
					</div>
					<div class="panel-footer text-center">
						<button class='btn btn-primary' type="submit" name="submit"><?php echo $lang[ "unblock submit" ]; ?></button>
					</div>
				</div>
			</div>
		</div>
	</form>

	<br />
	<?php
		if ( !empty( $_POST ) )
        {
			$alert      = '';
			$message    = '';
			$pieces     = explode( ".", php_uname( 'n' ) );
			$date       = @date( 'M j H:i:s' ). " " . $pieces[ 0 ] . " ";

			if ( isset( $_POST[ 'g-recaptcha-response' ] ) && !empty( $_POST[ 'g-recaptcha-response' ] ) )
            {
				$data       = array( 'secret' => $secret,'response' => $_POST[ 'g-recaptcha-response' ] );
				$verify     = curl_init( );

                /*
                    @note           curl_close() no-op in PHP 8.0; deprecated since PHP 8.5
                    @ref            https://www.php.net/manual/en/migration85.deprecated.php
                */

				curl_setopt( $verify, CURLOPT_URL,              "https://www.google.com/recaptcha/api/siteverify"   );
				curl_setopt( $verify, CURLOPT_POST,             true                                                );
				curl_setopt( $verify, CURLOPT_POSTFIELDS,       http_build_query( $data )                           );
				curl_setopt( $verify, CURLOPT_SSL_VERIFYPEER,   false                                               );
				curl_setopt( $verify, CURLOPT_RETURNTRANSFER,   true                                                );
				curl_setopt( $verify, CURLOPT_CONNECTTIMEOUT,   20                                                  );
				curl_setopt( $verify, CURLOPT_TIMEOUT,          30                                                  );

				$verifyResponse     = curl_exec( $verify );
				$curlError          = curl_error( $verify );
				$curlErrno          = curl_errno( $verify );
				$httpCode           = curl_getinfo( $verify, CURLINFO_HTTP_CODE );
				$curlError          = $curlError === '' ? 'None' : $curlError;

				if ( $verifyResponse === false )
				{
					$responseData = null;
				}
				else
				{
					$responseData = json_decode( $verifyResponse );
				}

				file_put_contents( $logfile, $date . "*Debug*, ReCaptcha verification request ( HTTP: $httpCode | cURL: $curlErrno | Error: $curlError )\n", FILE_APPEND | LOCK_EX );

				if ( $verifyResponse !== false && json_last_error( ) !== JSON_ERROR_NONE )
				{
                    /* 
                        json_last_error_msg: PHP 5 >= 5.5.0, PHP 7, PHP 8
                        Could break in PHP 5.3/4.

                        @ref            https://www.php.net/manual/en/function.json-last-error-msg.php
                    */

					if ( function_exists( 'json_last_error_msg' ) )
						file_put_contents( $logfile, $date . "*Debug*, ReCaptcha JSON decode failed: " . json_last_error_msg( ) . "\n", FILE_APPEND | LOCK_EX );
					else
						file_put_contents( $logfile, $date . "*Debug*, ReCaptcha JSON decode failed ( Error Code: " . json_last_error( ) . " )\n", FILE_APPEND | LOCK_EX );
				}

                if ( is_object( $responseData ) && isset( $responseData->success ) && $responseData->success && isset( $responseData->hostname ) )
                {
					file_put_contents( $logfile, $date . "*Debug*, ReCaptcha hostname check ( Google: [$responseData->hostname] | Server: [" . $_SERVER[ 'SERVER_NAME' ] . "] )\n", FILE_APPEND | LOCK_EX );

					if ( $responseData->hostname == $_SERVER[ 'SERVER_NAME' ] )
                    {
                        /*
                            ENT_SUBSTITUTE      Replace invalid code unit sequences with a Unicode Replacement
                                                Character U+FFFD (UTF-8) or &#xFFFD; (otherwise) instead of
                                                returning an empty string. 

                                                Added in PHP 5.4

                                                https://php.watch/codex/ENT_SUBSTITUTE

                            ENT_QUOTES          Will convert both double and single quotes.

                                                https://php.watch/codex/ENT_QUOTES
                        */

						$alert      = 'success';
                        $htmlFlags  = defined( 'ENT_SUBSTITUTE' ) ? ENT_QUOTES | ENT_SUBSTITUTE : ENT_QUOTES;
						$requestURI = htmlspecialchars( $_SERVER[ 'REQUEST_URI' ], $htmlFlags, 'UTF-8' );
						$message    = $lang[ "recaptcha success" ] . "<br /><a href='" . $requestURI . "'>" . $requestURI . "</a>";
						$entry      = $_SERVER[ 'REMOTE_ADDR' ].";".$_SERVER[ 'SERVER_NAME' ].";".$_SERVER[ 'SERVER_ADDR' ]."\n";

						file_put_contents( $logfile, $date . "*Debug*, ReCaptcha preparing unblock entry ( File: [$unblockfile] | Remote IP: [" . $_SERVER[ 'REMOTE_ADDR' ] . "] | Host: [" . $_SERVER[ 'SERVER_NAME' ] . "] | Server IP: [" . $_SERVER[ 'SERVER_ADDR' ] . "] )\n", FILE_APPEND | LOCK_EX );

						$written    = file_put_contents( $unblockfile, $entry, FILE_APPEND | LOCK_EX );

                        if ( $written === false )
                        {
                            $error  = error_get_last( );
                            $reason = isset( $error[ 'message' ] ) ? $error[ 'message' ] : 'Unknown error';
                        
                            file_put_contents( $logfile, $date . "*Failed*, ReCaptcha unable to write to [$unblockfile]: $reason\n", FILE_APPEND | LOCK_EX );
                        }
                        else
                        {
							file_put_contents( $logfile, $date . "*Debug*, ReCaptcha wrote [$written] bytes to [$unblockfile]: $entry", FILE_APPEND | LOCK_EX );
                            file_put_contents( $logfile, $date . "*Success*, ReCaptcha (" . $_SERVER[ 'REMOTE_ADDR' ] . "): [" . $_SERVER[ 'SERVER_NAME' ] . " (" . $_SERVER[ 'SERVER_ADDR' ] . ")] requested unblock\n", FILE_APPEND | LOCK_EX );
						}
					}
                    else
                    {
						$alert              = "danger";
                        $htmlFlags          = defined( 'ENT_SUBSTITUTE' ) ? ENT_QUOTES | ENT_SUBSTITUTE : ENT_QUOTES;
						$googleHostname     = htmlspecialchars( $responseData->hostname, $htmlFlags, 'UTF-8' );
						$serverHostname     = htmlspecialchars( $_SERVER[ 'SERVER_NAME' ], $htmlFlags, 'UTF-8' );
						$message            = $lang[ "recaptcha hostfail" ] . ' [' . $googleHostname . ' != ' . $serverHostname . ']';

                        file_put_contents( $logfile, $date . "*Failed*, ReCaptcha (" . $_SERVER[ 'REMOTE_ADDR' ] . "): [" . $_SERVER[ 'SERVER_NAME' ] . " (" . $_SERVER[ 'SERVER_ADDR' ] . ")] does not appear to be hosted on this server\n", FILE_APPEND | LOCK_EX );
					}
				}
                else
                {
					$alert          = "danger";
					$message        = $lang[ "recaptcha failure" ];
                    $errorCodes     = is_object( $responseData ) && isset( $responseData->{'error-codes'} ) && is_array( $responseData->{'error-codes'} ) ? implode( ", ", $responseData->{'error-codes'} ) : "none";

					file_put_contents( $logfile, $date . "*Error*, ReCaptcha (" . $_SERVER[ 'REMOTE_ADDR' ] . ") verification failed ( Error Codes: [$errorCodes] )\n", FILE_APPEND | LOCK_EX );
				}
			}
			else
            {
				$alert      = "danger";
				$message    = $lang[ "recaptcha error" ];

				file_put_contents( $logfile, $date . "*Debug*, ReCaptcha request received without g-recaptcha-response\n", FILE_APPEND | LOCK_EX );
			}
			echo '<div class="alert alert-' . $alert . '"><h4>' . $message . '</h4></div>';
		}
	?>

	<div class="alert alert-info"><?php echo $lang[ "recaptcha note" ]; ?></div>
</div>
</body>
</html>
