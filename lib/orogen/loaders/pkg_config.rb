module OroGen
    module Loaders
        # A loader that accesses the information from the pkg-config files
        # installed by oroGen.
        #
        # It allows to query oroGen-related information from the installed
        # oroGen projects, as well as load the corresponding models. It assumes
        # that the set of installed orogen projects is self-consistent.
        #
        # It accesses the local file system
        class PkgConfig < Base
            Project = Struct.new :pkg, :orogen_path
            TaskLibrary = Struct.new :pkg
            Type = Struct.new :name, :exported

            # @return [String] the name of the orocos target we are looking for
            attr_reader :orocos_target
            # @return [Hash<String,Project>] the set of known projects
            attr_reader :available_projects
            # @return [Hash<String,Utilrb::PkgConfig>] the set of known typekits
            attr_reader :available_typekits
            # @return [Hash<String,Utilrb::PkgConfig>] the set of known task libraries
            attr_reader :available_task_libraries
            # @return [Hash<String,String>] the set of known task
            #   models, as a mapping from the task model to the name of the task
            #   library that defines it
            attr_reader :available_task_models
            # @return [Hash<String,Utilrb::PkgConfig>] the set of known
            #   deployments
            attr_reader :available_deployments
            # @return [Hash<String,Set<String>>] the set of known
            #   deployments on a per-task-model basis
            attr_reader :available_deployed_tasks
            # @return [Hash<String,Type>] the set of known
            #   deployments on a per-task-model basis
            attr_reader :available_types

            # @param [String] orocos_target the orocos target we are loading for
            # @param root_loader the root loader. Other loaders might pass it
            #   instead of themselves to the {Spec::Project} objects so that
            #   they use the root loader to get their dependencies. The
            #   pkg-config loader assumes that we have a self-consistent set of
            #   packages on disk (since it is installed packages), and therefore
            #   does not use it.
            def initialize(orocos_target, root_loader = nil)
                @orocos_target = orocos_target
                update
                super()
            end

            # Registers a project from its pkg-config object
            #
            # @param [Utilrb::PkgConfig] the pkg-config from the project
            #   (orogen-project-NAME)
            # @return [Project] the registered project
            def add_project_from(pkg)
                project = pkg.project_name
                if project.empty?
                    OroGen.warn "#{pkg.name}.pc does not have a project_name field"
                end
                if description = available_projects[project]
                    return description
                end

                if pkg.deffile.empty?
                    OroGen.warn "#{pkg.name}.pc does not have a deffile field"
                else
                    available_projects[pkg.project_name] = Project.new(pkg, pkg.deffile)
                end
            end

            # Tests if a typekit with that name exists
            #
            # @param [String] the typekit name
            # @return [Boolean]
            def has_typekit?(name)
                available_typekits.has_key?(name)
            end

            # Returns the textual representation of a project model
            #
            # @param [String] the project name
            # @raise [OroGen::NotFound] if there is no project with that
            #   name.
            # @return [(String,String)] the model as text, as well as a path to
            #   the model file (or nil if there is no such file)
            def project_model_text_from_name(name)
                name = name.to_str
                if !(pkg = available_projects[name])
                    raise OroGen::NotFound, "cannot find an installed oroGen project called #{name}"
                end
                return File.read(pkg.orogen_path), pkg.orogen_path
            end

            # Returns the textual representation of a typekit
            #
            # @param [String] the typekit name
            # @raise [OroGen::NotFound] if there is no typekit with that name
            # @return [(String,String)] the typekit registry as XML and the
            #   typekit's typelist
            def typekit_model_text_from_name(name)
                if !(pkg = available_typekits[name])
                    raise OroGen::NotFound, "cannot find an installed typekit called #{name}"
                end

                registry = File.read(pkg.type_registry)
                typelist = File.join(File.dirname(pkg.type_registry), "#{name}.typelist")
                typelist = File.read(typelist)
                return registry, typelist
            end

            # Returns the task library name in which a task model is defined
            #
            # @param [String] model_name the name of the task model to look for
            # @return [String,nil]
            def find_task_library_from_task_model_name(model_name)
                available_task_models[model_name]
            end

            # Returns the project that defines the given deployment
            #
            # @param [String] deployment_name the deployment we are looking for
            # @return [String,nil]
            def find_project_from_deployment_name(deployment_name)
                if pkg = available_deployments[deployment_name]
                    pkg.project_name
                end
            end

            # Returns the set of deployments that contain a certain task
            #
            # @param [String] name
            # @return [Set<String>]
            def find_deployments_from_deployed_task_name(name)
                available_deployed_tasks[name] || Set.new
            end

            def update
                @available_projects = Hash.new
                @available_task_libraries = Hash.new
                @available_deployments = Hash.new
                @available_deployed_tasks = Hash.new
                @available_task_models = Hash.new
                @available_typekits = Hash.new
                @available_types = Hash.new

                Utilrb::PkgConfig.each_package(/^orogen-project-/) do |pkg_name|
                    pkg = Utilrb::PkgConfig.new(pkg_name)
                    add_project_from(pkg)
                end

                Utilrb::PkgConfig.each_package(/-tasks-#{orocos_target}$/) do |pkg_name|
                    pkg = Utilrb::PkgConfig.new(pkg_name)
                    tasklib_name = pkg_name.gsub(/-tasks-#{orocos_target}$/, '')

                    # Verify that the corresponding orogen project is indeed
                    # available. If not, just ignore the library
                    if !available_projects.has_key?(pkg.project_name)
                        OroGen.warn "found task library #{tasklib_name}, but the corresponding oroGen project #{pkg.project_name} could not be found. Consider deleting #{pkg.path}."
                        next
                    end

                    available_task_libraries[tasklib_name] = pkg
                    pkg.task_models.split(",").
                        each { |class_name| available_task_models[class_name] = tasklib_name }
                end

                Utilrb::PkgConfig.each_package(/^orogen-\w+$/) do |pkg_name|
                    pkg = Utilrb::PkgConfig.new(pkg_name)
                    deployment_name = pkg_name.gsub(/^orogen-/, '')

                    # Verify that the corresponding orogen project is indeed
                    # available. If not, just ignore the library
                    if !available_projects.has_key?(pkg.project_name)
                        OroGen.warn "found deployment #{deployment_name}, but the corresponding oroGen project #{pkg.project_name} could not be found. Consider deleting #{pkg.path}."
                        next
                    end

                    available_deployments[deployment_name] = pkg
                    pkg.deployed_tasks.split(',').each do |deployed_task_name|
                        available_deployed_tasks[deployed_task_name] ||= Set.new
                        available_deployed_tasks[deployed_task_name] << deployment_name
                    end
                end

                Utilrb::PkgConfig.each_package(/-typekit-#{orocos_target}$/) do |pkg_name|
                    pkg = Utilrb::PkgConfig.new(pkg_name)
                    typekit_name = pkg_name.gsub(/-typekit-#{orocos_target}$/, '')

                    if !available_projects.has_key?(pkg.project_name)
                        OroGen.warn "found typekit #{typekit_name}, but the corresponding oroGen project #{pkg.project_name} could not be found. Consider deleting #{pkg.path}."
                        next
                    elsif !available_projects[pkg.project_name].pkg.type_registry
                        OroGen.warn "found typekit #{typekit_name}, but the corresponding oroGen project #{pkg.project_name} does not have a typekit. Consider deleting #{pkg.path}."
                        next
                    end
                    available_typekits[typekit_name] = pkg

                    typelist = pkg.type_registry.gsub(/tlb$/, 'typelist')
                    typelist, typelist_exported =
                        OroGen::Spec::Typekit.parse_typelist(File.read(typelist))
                    typelist = typelist - typelist_exported
                    typelist.compact.each do |typename|
                        if existing = available_types[typename]
                            OroGen.info "#{typename} is defined by both #{existing[0]} and #{typekit_name}"
                        else
                            available_types[typename] = Type.new(typekit_name, false)
                        end
                    end
                    typelist_exported.compact.each do |typename|
                        if existing = available_types[typename]
                            OroGen.info "#{typename} is defined by both #{existing[0]} and #{typekit_name}"
                        end
                        available_types[typename] = Type.new(typekit_name, true)
                    end
                end
            end
        end
    end
end