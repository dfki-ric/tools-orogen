# frozen_string_literal: true

require "orogen"

module OroGen
    module Gen
        extend Logger::Hierarchy

        module RTT_CPP
            extend Logger::Hierarchy

            ConfigError = OroGen::ConfigError
            OROGEN_LIB_DIR = OroGen::OROGEN_LIB_DIR

            ConfigurationObject = Spec::ConfigurationObject
            Attribute           = Spec::Attribute
            Property            = Spec::Property

            Operation           = Spec::Operation

            Port                = Spec::Port
            OutputPort          = Spec::OutputPort
            InputPort           = Spec::InputPort
            DynamicInputPort    = Spec::DynamicInputPort
            DynamicOutputPort   = Spec::DynamicInputPort

            TaskContext         = Spec::TaskContext
        end
    end
    Generation = Gen::RTT_CPP
end

require "orogen/gen/enable"
require "orogen/gen/base"
require "orogen/gen/templates"
require "orogen/gen/typekit"
require "orogen/marshallers"
require "orogen/gen/deployment"
require "orogen/gen/tasks"
require "orogen/gen/project"
require "orogen/gen/imports"
OroGen::Gen::RTT_CPP::Typekit.register_plugin(OroGen::TypekitMarshallers::ROS::Plugin)
OroGen::Gen::RTT_CPP::Typekit.register_plugin(OroGen::TypekitMarshallers::Corba::Plugin)
OroGen::Gen::RTT_CPP::Typekit.register_plugin(OroGen::TypekitMarshallers::MQueue::Plugin)
OroGen::Gen::RTT_CPP::Typekit.register_plugin(OroGen::TypekitMarshallers::TypeInfo::Plugin)
OroGen::Gen::RTT_CPP::Typekit.register_plugin(OroGen::TypekitMarshallers::TypelibMarshaller::Plugin)

OroGen::Gen::RTT_CPP::Deployment.register_global_initializer(
    :qt,
    global_scope: <<~QT_GLOBAL_SCOPE,
        static int QT_ARGC = 1;
        static char const* QT_ARGV[] = { "orogen", nullptr };
        #include <pthread.h>
        #include <QApplication>

        void* qt_thread_main(void*)
        {
            QApplication *qapp = new QApplication(QT_ARGC, const_cast<char**>(QT_ARGV));
            qapp->setQuitOnLastWindowClosed(false);
            // NOTE: we do NOT need to explicitely synchronize with the QApplication
            // startup. The only safe way to interact with parts of Qt that require
            // an event loop is through postEvent, which is safe to use even before
            // the QApplication gets created

            qapp->exec();
            return NULL;
        }
    QT_GLOBAL_SCOPE
    init: <<~QT_INIT_CODE,
        pthread_t qt_thread;
        pthread_create(&qt_thread, NULL, qt_thread_main, NULL);
    QT_INIT_CODE
    exit: <<~QT_EXIT_CODE,
        QApplication::instance()->exit();
        pthread_join(qt_thread, NULL);
    QT_EXIT_CODE
    tasks_cmake: <<~QT_DEPLOYMENT_CMAKE,
        find_package(Qt4 REQUIRED)
        include(${QT_USE_FILE})
        include_directories(${QT_INCLUDE_DIR})
        link_directories(${QT_LIBRARY_DIR})
        set(CMAKE_AUTOMOC true)

        target_link_libraries(${<%= project.name.upcase %>_TASKLIB_NAME}
            ${OrocosRTT_LIBRARIES}
            ${QT_LIBRARIES}
            ${<%= project.name.upcase %>_TASKLIB_DEPENDENT_LIBRARIES})
    QT_DEPLOYMENT_CMAKE
    deployment_cmake: <<~QT_DEPLOYMENT_CMAKE,
        find_package(Qt4 REQUIRED)
        include(${QT_USE_FILE})
        include_directories(${QT_INCLUDE_DIR})
        link_directories(${QT_LIBRARY_DIR})
        target_link_libraries(<%= deployer.name %> ${QT_LIBRARIES})
        set(CMAKE_AUTOMOC true)
    QT_DEPLOYMENT_CMAKE
)

OroGen::Gen::RTT_CPP::Deployment.register_global_initializer(
    :qt5,
    global_scope: <<~QT_GLOBAL_SCOPE,
        static int QT_ARGC = 1;
        static char const* QT_ARGV[] = { "orogen", nullptr };
        #include <pthread.h>
        #include <QApplication>

        void* qt_thread_main(void*)
        {
            QApplication *qapp = new QApplication(QT_ARGC, const_cast<char**>(QT_ARGV));
            qapp->setQuitOnLastWindowClosed(false);
            // NOTE: we do NOT need to explicitely synchronize with the QApplication
            // startup. The only safe way to interact with parts of Qt that require
            // an event loop is through postEvent, which is safe to use even before
            // the QApplication gets created

            qapp->exec();
            return NULL;
        }
    QT_GLOBAL_SCOPE
    init: <<~QT_INIT_CODE,
        pthread_t qt_thread;
        pthread_create(&qt_thread, NULL, qt_thread_main, NULL);
    QT_INIT_CODE
    exit: <<~QT_EXIT_CODE,
        QApplication::instance()->exit();
        pthread_join(qt_thread, NULL);
    QT_EXIT_CODE
    tasks_cmake: <<~QT_DEPLOYMENT_CMAKE,
        find_package(Rock REQUIRED)
        rock_find_qt5(Core Gui Widgets UiTools)
        target_link_libraries(${<%= project.name.upcase %>_TASKLIB_NAME} PUBLIC
            ${OrocosRTT_LIBRARIES}
            Qt5::Core
            Qt5::Gui
            Qt5::Widgets
            Qt5::UiTools
            ${<%= project.name.upcase %>_TASKLIB_DEPENDENT_LIBRARIES})
        set(CMAKE_AUTOMOC true)
    QT_DEPLOYMENT_CMAKE
    deployment_cmake: <<~QT_DEPLOYMENT_CMAKE,
        find_package(Rock REQUIRED)
        rock_find_qt5(Core Gui Widgets UiTools)
        target_link_libraries(<%= deployer.name %> Qt5::Core Qt5::Gui Qt5::Widgets Qt5::UiTools)
        set(CMAKE_AUTOMOC true)
    QT_DEPLOYMENT_CMAKE
    tasklib_cmake: <<~QT_DEPLOYMENT_CMAKE,
        <%=
        qt5_deps = []
        qt5_core = BuildDependency.new("Qt5Core", "Qt5Core")
        qt5_core.in_context("core", "include")
        qt5_core.in_context("core", "link")
        qt5_deps << qt5_core
        qt5_gui = BuildDependency.new("Qt5Gui", "Qt5Gui")
        qt5_gui.in_context("core", "include")
        qt5_gui.in_context("core", "link")
        qt5_deps << qt5_gui
        qt5_widgets = BuildDependency.new("Qt5Widgets", "Qt5Widgets")
        qt5_widgets.in_context("core", "include")
        qt5_widgets.in_context("core", "link")
        qt5_deps << qt5_widgets
        qt5_uitools = BuildDependency.new("Qt5UiTools", "Qt5UiTools")
        qt5_uitools.in_context("core", "include")
        qt5_uitools.in_context("core", "link")
        qt5_deps << qt5_uitools
        Generation.cmake_pkgconfig_require(qt5_deps)
        %>

        list(APPEND <%= project.name.upcase %>_TASKLIB_DEPENDENT_LIBRARIES ${Qt5Core_LIBRARIES})
        list(APPEND <%= project.name.upcase %>_TASKLIB_DEPENDENT_LIBRARIES ${Qt5Gui_LIBRARIES})
        list(APPEND <%= project.name.upcase %>_TASKLIB_DEPENDENT_LIBRARIES ${Qt5Widgets_LIBRARIES})
        list(APPEND <%= project.name.upcase %>_TASKLIB_DEPENDENT_LIBRARIES ${Qt5UiTools_LIBRARIES})
    QT_DEPLOYMENT_CMAKE
)
