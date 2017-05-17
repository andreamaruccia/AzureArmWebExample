Configuration vmBootstrap
{
  param ($someparam)

  Node localhost
  {
    Environment EnvironmentExample
    {
        Ensure = "Present"
        Name = "TestEnvironmentVariable"
        Value = "TestValue"
    }   
  }
} 