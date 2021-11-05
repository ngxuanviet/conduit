# Starting and Stopping an Application

Learn how an application is initialized so it can serve requests.

## Overview

Applications are started by running `conduit serve` or `dart bin/main.script` in a Conduit project directory. Either way, a number of threads are created and your `ApplicationChannel` subclass is instantiated on each thread. The channel subclass initializes application behavior which is often the following:

* reads configuration data for environment specific setup
* initializes service objects like [database connections](channel.md)
* sets up [controller](../http/controller.md) objects to handle requests

### Initializing ApplicationChannel Controllers

Each application channel has an _entry point_ - a controller that handles all incoming requests. This controller is often a router that routes requests to an appropriate handler. Every controller that will be used in the application is linked to either the entry point in some way. Here's an example:

```dart
class AppChannel extends ApplicationChannel {
  @override
  Controller get entryPoint {
    final router = new Router();

    router
      .route("/users")
      .link(() => Authorizer())
      .link(() => UserController());

    return router;
  }
}
```

This method links together a `Router` -&gt; `Authorizer` -&gt; `UserController`. Because the router is returned from this method, it handles all incoming requests. It will pass a request to an `Authorizer` when the request path is `/users`, which will then pass that request to a `UserController` if it is authorized.

All controllers in your application will be linked to the entry point, either directly or indirectly.

!!! note "Linking Controllers" The `link()` method takes a closure that creates a new controller. Some controllers get instantiated for each request, and others get reused for every request. See [the chapter on controllers](../http/controller.md) for more information.

## Initializing Service Objects

Controllers often need to get \(or create\) information from outside the application. The most common example is database access, but it could be anything: another REST API, a connected device, etc. A _service object_ encapsulates the information and behavior needed to work with an external system. This separation of concerns between controllers and service objects allows for better structured and more testable code.

Service objects are instantiated by overriding `ApplicationChannel.prepare`.

```dart
class AppChannel extends ApplicationChannel {
  PostgreSQLConnection database;

  @override
  Future prepare() async {
    database = PostgreSQLConnection();
  }

  @override
  Controller get entryPoint {
    final router = new Router();

    router
      .route("/users")
      .link(() => new Authorizer())
      .link(() => new UserController(database));

    return router;
  }
}
```

This methods gets invoked before `entryPoint`. You store created services in instance variables so that you can inject them into controllers in `entryPoint`. Services are injected through a controller's constructor arguments. For example, the above shows a `database` service that is injected into `UserController`.

## Application Channel Configuration

A benefit to using service objects is that they can be altered depending on the environment the application is running in without requiring changes to code. For example, the database an application will connect to will be different when running in production than when running tests.

Besides service configuration, there may be other types of initialization an application wants to take. Common tasks include adding codecs to `CodecRegistry` or setting the default `CORSPolicy`. All of this initialization is done in `prepare()`.

Some of the information needed to configure an application will come from a configuration file or environment variables. For more information on using a configuration file and environment variables to guide initialization, see [this guide](configure.md).

## Multi-threaded Conduit Applications

Conduit applications can - and should - be spread across a number of threads. This allows an application to take advantage of multiple CPUs and serve requests faster. In Dart, threads are called _isolates_. An instance of your `ApplicationChannel` is created for each isolate. When your application receives an HTTP request, the request is passed to one of these instances' entry points. These instances are replicas of one another and it doesn't matter which instance processes the request. This isolate-channel architecture is very similar to running multiple servers that run the same application.

The number of isolates an application will use is configurable at startup when using the [conduit serve](../cli/running.md) command.

An isolate can't share memory with another isolate. If an object is created on one isolate, it _cannot_ be referenced by another. Therefore, each `ApplicationChannel` instance has its own set of services that are configured in the same way. This behavior also makes design patterns like connection pooling implicit; instead of a pool of database connections, there is a pool of application channels that each have their own database connection.

This architecture intentionally prevents you from keeping state in your application. When you scale to multiple servers, you can trust that your cluster works correctly because you are already effectively clustering on a single server node. For further reading on writing multi-threaded applications, see [this guide](threading.md).

## Initialization Callbacks

Both `prepare()` and `entryPoint` are part of the initialization process of an application channel. Most applications only ever need these two methods. Another method, that is rarely used, is `willStartReceivingRequests()`. This method is called after `prepare()` and `entryPoint` have been executed, and right before your application will start receiving requests.

These three initialization callbacks are called once per isolate to initialize the channel running on that isolate. For initialization that should only occur _once per application start_ \(regardless of how many isolates are running\), an `ApplicationChannel` subclass can implement a static method named `initializeApplication()`.

```dart
class AppChannel extends ApplicationChannel {
  static Future initializeApplication(ApplicationOptions options) async {
    ... do one time setup ...
  }

  ...
}
```

This method is invoked before any `ApplicationChannel` instances are created. Any changes made to `options` will be available in each `ApplicationChannel`'s `options` property.

For example:

```dart
class AppChannel extends ApplicationChannel {

  static Future initializeApplication(ApplicationOptions options) async {        
    options.context["special item"] = "xyz";
  }  

  Future prepare() async {
    var parsedConfigValues = options.context["special item"]; // == xyz
    ...
  }
}
```

Each isolate has its own heap. `initializeApplication` is executed in the main isolate, whereas each `ApplicationChannel` is instantiated in its own isolate. This means that any values stored in `ApplicationOptions` must be safe to pass across isolates - i.e., they can't contain references to closures.

Additionally, any global variables or static properties that are set in the main isolate _will not be set_ in other isolates. Configuration types like `CodecRegistry` do not share values across isolates, because they use a static property to hold a reference to the repository of codecs. Therefore, they must be set up in `ApplicationChannel.prepare()`.

Also, because static methods cannot be overridden in Dart, it is important that you ensure the name and signature of `initializeApplication` exactly matches what is shown in these code samples. The analyzer can't help you here, unfortunately.

## Application Channel File

An `ApplicationChannel` subclass is most often declared in its own file named `lib/channel.dart`. This file must be exported from the application library file. For example, if the application is named `wildfire`, the application library file is `lib/wildfire.dart`. Here is a sample directory structure:

```text
wildfire/
  lib/
    wildfire.dart
    channel.dart
    controllers/
      user_controller.dart      
    ...
```

See [this guide](structure.md) for more details on how a Conduit application's files are structured.

## Lazy Services

Many service objects will establish a persistent network connection. A network connection can sometimes be interrupted and have to re-establish itself. If these connections are only opened when the application first starts, the application will not be able to reopen these connections without restarting the application. This would be very bad.

For that reason, services should manage their own connectivity behavior. For example, a database connection should connect it when it is asked to execute a query. If it already has a valid connection, it will go ahead and execute the query. Otherwise, it will establish the connection and then execute the query. The caller doesn't care - it gets a `Future` with the desired result.

The pseudo-code looks something like this:

```dart
Future execute(String sql) async {
  if (connection == null || !connection.isAvailable) {
    connection = new Connection(...);
    await connection.open();
  }

  return connection.executeSQL(sql);
}
```

## The Application Object

Hidden in all of this discussion is the `Application<T>` object. Because the `conduit serve` command manages creating an `Application<T>` instance, your code rarely concerns itself with this type.

An `Application<T>` is the top-level object in a Conduit application; it sets up HTTP listeners and directs requests to `ApplicationChannel`s. The `Application<T>` itself is just a generic container for `ApplicationChannel`s; it doesn't do much other than kick everything off.

The application's `start` method will initialize at least one instance of the application's `ApplicationChannel`. If something goes wrong during this initialization process, the application will throw an exception and halt starting the server. For example, setting up an invalid route in a `ApplicationChannel` subclass would trigger this type of startup exception.

An `Application<T>` has a number of options that determine how it will listen for HTTP requests, such as which port it is listening on or the SSL certificate it will use. These values are available in the channel's `options` property, an instance of `ApplicationOptions`.

