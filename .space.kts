job("Build, push budibase image") {
    kaniko(displayName = "Build image and push into container registry") {
        build {
            context = "."
        }

        push("YOUR_REGISTRY/company-budibase-aas:latest") #replace YOUR_REGISTRY
    }
}