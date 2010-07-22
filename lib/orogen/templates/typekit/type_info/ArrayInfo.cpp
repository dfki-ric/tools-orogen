#include <<%= typekit.name %>TypekitTypes.hpp>
#include <rtt/internal/carray.hpp>
#include <<%= type.info_type_header %>>

namespace orogen_typekits {
    struct <%= type.deference.method_name(true) %>ArrayTypeInfo :
	public <%= type.info_type %>< RTT::internal::carray< <%= type.deference.cxx_name %> > >
    {
        <%= type.deference.method_name(true) %>ArrayTypeInfo()
            : <%= type.info_type %>< RTT::internal::carray< <%= type.deference.cxx_name %> > >("<%= type.deference.full_name %>[]") {}
    };

    RTT::types::TypeInfo* <%= type.deference.method_name(true) %>_ArrayTypeInfo()
    { return new <%= type.deference.method_name(true) %>ArrayTypeInfo(); }
}

