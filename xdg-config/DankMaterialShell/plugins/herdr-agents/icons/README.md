# Robot artwork

The `robot` and `robot-outline` icons are from
[Pictogrammers Material Design Icons](https://pictogrammers.com/library/mdi/).

- Original filled shape: https://pictogrammers.com/library/mdi/icon/robot/
- Original outlined shape: https://pictogrammers.com/library/mdi/icon/robot-outline/
- Upstream license: https://github.com/Templarian/MaterialDesign/blob/master/LICENSE

The supplied original SVGs are retained here as regression fixtures, unchanged
apart from a trailing newline. The widget renders their path data directly
through native QML `PathSvg`, not by loading these images.

## Modifications

`HerdrWidget.qml` adapts both paths: eye radii are reduced by 25% around the
original centers. The remaining body geometry is unchanged. Status color is
applied by QML. Documentation previews use these adapted paths as well.

The artwork and adapted path data are licensed under Apache-2.0, not under the
plugin code's MIT license. The upstream license notice is retained in
`UPSTREAM-LICENSE`; the full Apache license is in `LICENSE-APACHE-2.0`.
