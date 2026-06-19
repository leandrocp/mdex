%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.TagTODO, false}
      ]
    }
  ]
}
