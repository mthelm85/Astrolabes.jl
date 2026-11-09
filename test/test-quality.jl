@testitem "Aqua" tags = [:quality] begin
    using Aqua
    Aqua.test_all(Astrolabes)
end

@testitem "JET" tags = [:quality] begin
    using JET
    JET.test_package(Astrolabes; target_modules = (Astrolabes,))
end
