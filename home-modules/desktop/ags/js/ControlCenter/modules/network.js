import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import Network from 'resource:///com/github/Aylur/ags/service/network.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
import { Menu, ArrowToggleButton } from '../ToggleButton.js';

export const NetworkToggle = () => ArrowToggleButton({
    name: 'network',
    icon: Widget.Icon({
        connections: [[Network, icon => {
            icon.icon = Network.wifi.icon_name || '';
        }]],
    }),
    label: Widget.Label({
        truncate: 'end',
        connections: [[Network, label => {
            label.label = Network.wifi.ssid || 'Not Connected';
        }]],
    }),
    connection: [Network, () => Network.wifi.enabled],
    deactivate: () => Network.wifi.enabled = false,
    activate: () => {
        Network.wifi.enabled = true;
        Network.wifi.scan();
    },
});

export const WifiSelection = () => Menu({
    name: 'network',
    icon: Widget.Icon({
        connections: [[Network, icon => {
            icon.icon = Network.wifi.icon_name;
        }]],
    }),
    title: Widget.Label('Wifi Selection'),
    content: [
        Widget.Box({
            vertical: true,
            connections: [[Network, box => box.children =
                Network.wifi?.access_points.map(ap => Widget.Button({
                    on_clicked: () => Utils.execAsync(`nmcli device wifi connect ${ap.bssid}`),
                    child: Widget.Box({
                        children: [
                            Widget.Icon(ap.iconName),
                            Widget.Label(ap.ssid || ''),
                            ap.active && Widget.Icon({
                                icon: 'object-select-symbolic',
                                hexpand: true,
                                hpack: 'end',
                            }),
                        ],
                    }),
                })),
            ]],
        }),
    ],
});