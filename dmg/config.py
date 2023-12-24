# self-defined
_app = 'Fcitx5.app'
_im = 'Input Methods'

# recognized by dmgbuild
files = [f'/Library/{_im}/{_app}']
symlinks = { _im: f'/Library/{_im}' }
badge_icon = f'dmg/fcitx.icns'
icon_locations = {
    _app: (100, 130),
    _im: (470, 130)
}
background = 'dmg/background.tiff'
window_rect = (100, 100), (600, 300)
