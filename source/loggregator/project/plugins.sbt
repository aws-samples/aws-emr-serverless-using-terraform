resolvers += Resolver.url("sbt-plugin-releases-scala-sbt", url("http://repo.scala-sbt.org/scalasbt/sbt-plugin-releases/"))

addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "0.14.9")
addSbtPlugin("com.typesafe.sbt" % "sbt-native-packager" % "1.7.3")