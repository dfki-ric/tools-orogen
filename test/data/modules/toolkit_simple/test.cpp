#include <rtt/Toolkit.hpp>
#include "simpleToolkitTypes.hpp"
#include "simpleToolkit.hpp"

#ifdef WITH_CORBA
#include <omniORB4/CORBA.h>
#include <rtt/corba/CorbaLib.hpp>
#include "build/.orogen/toolkit/simpleToolkitC.h"
#endif

#include <rtt/os/main.h>
#include <rtt/Types.hpp>
#include <rtt/PropertyBag.hpp>
#include <rtt/DataSources.hpp>
#include <rtt/marsh/XMLMarshaller.hpp>
#include <rtt/marsh/PropertyMarshaller.hpp>
#include <rtt/marsh/PropertyDemarshaller.hpp>
#include <iostream>
#include <fstream>

using namespace RTT;
using std::cerr;
using std::endl;

namespace Test {
    extern std::ostream& operator << (std::ostream& io, Simple const& data);
}

template<typename T>
bool generic_type_handling_test(std::string const& name, T const& testValue, TypeInfo const& ti)
{
    ConstantDataSource<Test::Simple>* source
        = new ConstantDataSource<Test::Simple>(testValue);
    source->ref();

    PropertyBag bag;
    ti.decomposeType(source, bag);

    // First, save it into XML. The Ruby test case will compare that to an
    // expected XML document
    std::ofstream xml_file((name + ".xml").c_str());
    XMLMarshaller<std::ostream> xml_output(xml_file);
    xml_output.serialize(bag);

    // Now, marshal it to the standard Orocos format, reload it and compare
    // the result
    PropertyMarshaller cpf_output(name + ".cpf");
    cpf_output.serialize(bag);
    cpf_output.flush();

    PropertyBag input_bag;
    PropertyDemarshaller cpf_input(name + ".cpf");
    cpf_input.deserialize(input_bag);

    cerr << "Testing PropertyBag composition" << endl;
    { ValueDataSource<T>* reader = new ValueDataSource<T>();
        reader->ref();
        Property<PropertyBag> bag("", "", input_bag);
        if (!ti.composeType(bag.getDataSource(), reader))
        {
            cerr << "cannot recompose type" << endl;
            return false;
        }

        T value = reader->get();
        if (!(value == testValue))
        {
            cerr << "error. Expected\n\n" << testValue <<
                "\n\nand got\n\n" << value << endl;
        }
    }

#ifdef WITH_CORBA
    std::cerr << "Testing CORBA marshalling/unmarshalling ..." << std::endl;
    { CORBA::Any* result = reinterpret_cast<CORBA::Any*>(source->createBlob(ORO_CORBA_PROTOCOL_ID));
        ValueDataSource<T>* reader = new ValueDataSource<T>();
        reader->ref();
        reader->updateBlob(ORO_CORBA_PROTOCOL_ID, result);
        T value = reader->get();
        if (!(value == testValue))
        {
            cerr << "error. Expected\n\n" << testValue <<
                "\n\nand got\n\n" << value << endl;
        }
    }
#endif
    return true;
}

int ORO_main(int argc, char** argv)
{
    log().setLogLevel( Logger::Debug );
    RTT::Toolkit::Import( simple::Toolkit );

    TypeInfoRepository::shared_ptr ti = TypeInfoRepository::Instance();

    TypeInfo* type = ti->type("/Test/Simple");
    if (! type)
    {
	cerr << "cannot find /Test/Simple in the type info repository" << endl;
	return 1;
    }

    // Create a structure of type Test::Simple, inject it into Orocos and check
    // that it is able to generate a XML representation of it
    Test::Simple testValue = { 10, Test::VALUE_1, "" };
    for (int i = 0; i < 20; ++i)
	testValue.a[i] = 'a' + i;

    if (! generic_type_handling_test("simple", testValue, *type))
        return 1;

    return 0;
}
