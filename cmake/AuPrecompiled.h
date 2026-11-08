// Precompiled header shared by every code target (see cmake/AuBuildSpeed.cmake).
//
// Only stable third-party headers belong here. Project headers change often,
// and any change to this file rebuilds everything that uses it.
//
// Order matters: qgl.h must come before QtGui, matching augl.h.
#pragma once

#ifdef __cplusplus

#include <qgl.h>
#include <QtCore>
#include <QtGui>
#include <QtWidgets>

#include <QHostAddress>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTcpSocket>
#include <QUdpSocket>

#include <cmath>
#include <map>
#include <unordered_map>

#endif
