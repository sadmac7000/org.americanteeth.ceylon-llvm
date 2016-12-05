import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    FunctionOrValue,
    Function,
    Value,
    ParameterList,
    Parameter,
    Scope,
    Setter,
    Unit
}

import ceylon.interop.java {
    JavaList
}

abstract class FunctionOrValueData(name, type, annotations)
        extends DeclarationData() {
    shared actual formal FunctionOrValue declaration;

    shared String name;
    shared TypeData? type;
    shared AnnotationData annotations;

    shared actual default void complete(Module mod, Unit unit,
            Scope container) {
        value parentDeclaration =
            if (is Declaration container)
            then container
            else null;

        declaration.type = type?.toType(mod, unit, parentDeclaration);
    }
}

void applyParametersToFunction(Module mod, Unit unit, Function func,
        [ParameterListData+] parameterLists) {
    variable value first = true;

    for (data in parameterLists) {
        value p = data.toParameterList(mod, unit, func);
        p.namedParametersSupported = first;
        func.addParameterList(p);
        first = false;
    }
}

class FunctionData(n, t, a, typeParameters, declaredVoid, deferred, parameterLists)
        extends FunctionOrValueData(n, t, a) {
    String n;
    TypeData? t;
    AnnotationData a;
    [TypeParameterData*] typeParameters;
    shared Boolean declaredVoid;
    shared Boolean deferred;
    shared [ParameterListData+] parameterLists;

    value func = Function();

    func.name = n;
    func.declaredVoid = declaredVoid;
    func.deferred = deferred;
    a.apply(func);

    value reifiedTypeParameters =
        typeParameters.collect((x) => x.typeParameter);

    for (p in reifiedTypeParameters) {
        func.members.add(p);
    }

    func.typeParameters = JavaList(reifiedTypeParameters);

    shared actual Function declaration = func;

    shared actual void complete(Module mod, Unit unit, Scope container) {
        super.complete(mod, unit, container);
        applyParametersToFunction(mod, unit, func, parameterLists);

        for (t in typeParameters) {
            t.complete(mod, unit, func);
        }
    }
}

class ValueData(n, t, a, transient, static, \ivariable,
        setterAnnotations) extends FunctionOrValueData(n, t, a) {
    String n;
    TypeData t;
    AnnotationData a;
    shared Boolean transient;
    shared Boolean static;
    shared Boolean \ivariable;
    shared AnnotationData? setterAnnotations;

    shared Boolean hasSetter = setterAnnotations exists;

    value val = Value();
    val.name = n;
    val.transient = transient;
    val.static = static;
    val.\ivariable = \ivariable;
    a.apply(val);

    if (exists setterAnnotations) {
        val.setter = Setter();
        setterAnnotations.apply(val.setter);
        val.setter.name = val.name;
        val.setter.getter = val;
    }

    shared actual Value declaration = val;

    shared actual void complete(Module mod, Unit unit, Scope container) {
        super.complete(mod, unit, container);

        if (exists setterAnnotations) {
            val.setter.type = val.type;
        }
    }
}

class ParameterListData([ParameterData*] parameters) {
    shared ParameterList toParameterList(Module mod, Unit unit,
            Declaration container) {
        value ret = ParameterList();

        for (parameter in parameters) {
            ret.parameters.add(parameter.toParameter(mod, unit, container));
        }

        return ret;
    }
}

class ParameterType {
    shared new normal {}
    shared new zeroOrMore {}
    shared new oneOrMore {}
}

class ParameterData(name, hidden, defaulted, parameterType, parameters,
        type, annotations) {
    shared String name;
    shared Boolean hidden;
    shared Boolean defaulted;
    shared ParameterType parameterType;
    shared [ParameterListData*] parameters;
    shared TypeData type;
    shared AnnotationData annotations;

    shared Parameter toParameter(Module mod, Unit unit, Declaration container) {
        value ret = Parameter();

        ret.name = name;
        ret.declaration = container;
        ret.hidden = hidden;
        ret.defaulted = defaulted;
        ret.sequenced = parameterType != ParameterType.normal;
        ret.atLeastOne = parameterType == ParameterType.oneOrMore;

        FunctionOrValue f;

        if (nonempty parameters) {
            f = Function();
            assert(is Function f);
            applyParametersToFunction(mod, unit, f, parameters);
        } else {
            f = Value();
        }

        ret.model = f;
        f.initializerParameter = ret;
        f.name = name;
        f.unit = unit;

        if (is Scope container) {
            f.container = container;
        }

        f.type = type.toType(mod, unit, f);
        annotations.apply(f);

        return ret;
    }
}
