#!/usr/bin/python
# -*- encoding: utf-8; py-indent-offset: 4 -*-
# +------------------------------------------------------------------+
# |             ____ _               _        __  __ _  __           |
# |            / ___| |__   ___  ___| | __   |  \/  | |/ /           |
# |           | |   | '_ \ / _ \/ __| |/ /   | |\/| | ' /            |
# |           | |___| | | |  __/ (__|   <    | |  | | . \            |
# |            \____|_| |_|\___|\___|_|\_\___|_|  |_|_|\_\           |
# |                                                                  |
# | Copyright Mathias Kettner 2014             mk@mathias-kettner.de |
# +------------------------------------------------------------------+
#
# This file is part of Check_MK.
# The official homepage is at http://mathias-kettner.de/check_mk.
#
# check_mk is free software;  you can redistribute it and/or modify it
# under the  terms of the  GNU General Public License  as published by
# the Free Software Foundation in version 2.  check_mk is  distributed
# in the hope that it will be useful, but WITHOUT ANY WARRANTY;  with-
# out even the implied warranty of  MERCHANTABILITY  or  FITNESS FOR A
# PARTICULAR PURPOSE. See the  GNU General Public License for more de-
# tails. You should have  received  a copy of the  GNU  General Public
# License along with GNU Make; see the file  COPYING.  If  not,  write
# to the Free Software Foundation, Inc., 51 Franklin St,  Fifth Floor,
# Boston, MA 02110-1301 USA.

from cmk.gui.i18n import _
from cmk.gui.valuespec import (
    Integer,
    TextAscii,
    Tuple,
)
from cmk.gui.plugins.wato import (
    RulespecGroupCheckParametersEnvironment,
    CheckParameterRulespecWithItem,
    rulespec_registry,
)


def _item_spec_disk_temperature():
    return TextAscii(title=_("Hard disk device"),
                     help=_("The identificator of the hard disk device, e.g. <tt>/dev/sda</tt>."))


def _parameter_valuespec_disk_temperature():
    return Tuple(help=_("Temperature levels for hard disks, that is determined e.g. via SMART"),
                 elements=[
                     Integer(title=_("warning at"), unit=u"°C", default_value=35),
                     Integer(title=_("critical at"), unit=u"°C", default_value=40),
                 ])


rulespec_registry.register(
    CheckParameterRulespecWithItem(
        check_group_name="disk_temperature",
        group=RulespecGroupCheckParametersEnvironment,
        is_deprecated=True,
        item_spec=_item_spec_disk_temperature,
        parameter_valuespec=_parameter_valuespec_disk_temperature,
        title=lambda: _("Harddisk temperature (e.g. via SMART)"),
    ))
