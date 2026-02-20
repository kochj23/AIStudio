//
//  ComfyUIService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// ComfyUI REST + WebSocket client.
/// POST /prompt with workflow JSON, WebSocket for progress, GET /history/{prompt_id} for results.
actor ComfyUIService: ImageBackendProtocol {
    let backendType: BackendType = .comfyUI

    private var baseURL: String
    private let session: URLSession
    private let clientId: String
    private var webSocketTask: URLSessionWebSocketTask?

    init(baseURL: String = "http://localhost:8188") {
        self.baseURL = baseURL
        self.clientId = UUID().uuidString
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    func updateBaseURL(_ url: String) {
        self.baseURL = url
    }

    // MARK: - Health Check

    func checkHealth() async -> BackendStatus {
        guard let url = URL(string: "\(baseURL)/system_stats") else {
            return .error("Invalid URL")
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .connected
            }
            return .error("Unexpected response")
        } catch {
            return .disconnected
        }
    }

    // MARK: - Models (ComfyUI uses checkpoints)

    func listModels() async throws -> [A1111Model] {
        let data = try await get("/object_info/CheckpointLoaderSimple")
        // Parse the checkpoint list from the object_info response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let nodeInfo = json["CheckpointLoaderSimple"] as? [String: Any],
           let input = nodeInfo["input"] as? [String: Any],
           let required = input["required"] as? [String: Any],
           let ckptName = required["ckpt_name"] as? [[Any]],
           let names = ckptName.first as? [String] {
            return names.map { name in
                A1111Model(title: name, modelName: name, hash: nil, filename: name)
            }
        }
        return []
    }

    func listSamplers() async throws -> [A1111Sampler] {
        let data = try await get("/object_info/KSampler")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let nodeInfo = json["KSampler"] as? [String: Any],
           let input = nodeInfo["input"] as? [String: Any],
           let required = input["required"] as? [String: Any],
           let samplerName = required["sampler_name"] as? [[Any]],
           let names = samplerName.first as? [String] {
            return names.map { A1111Sampler(name: $0, aliases: nil) }
        }
        return []
    }

    // MARK: - Text to Image

    func textToImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        let startTime = Date()

        let workflow = buildTxt2ImgWorkflow(request)
        let promptData = try JSONSerialization.data(withJSONObject: [
            "prompt": workflow,
            "client_id": clientId
        ])

        let responseData = try await post("/prompt", body: promptData)

        guard let responseJSON = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let promptId = responseJSON["prompt_id"] as? String else {
            throw BackendError.decodingFailed("No prompt_id in response")
        }

        // Poll for completion
        let images = try await pollForImages(promptId: promptId)

        let generationTime = Date().timeIntervalSince(startTime)
        let metadata = GenerationMetadata(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            steps: request.steps,
            samplerName: request.samplerName,
            cfgScale: request.cfgScale,
            width: request.width,
            height: request.height,
            seed: request.seed,
            backendName: "ComfyUI",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    // MARK: - Image to Image

    func imageToImage(_ request: ImageToImageRequest) async throws -> ImageGenerationResult {
        let startTime = Date()

        // Upload the init image first
        guard let firstImage = request.initImages.first,
              let imageData = Data(base64Encoded: firstImage) else {
            throw BackendError.invalidImageData
        }

        let imageName = try await uploadImage(imageData, filename: "input_\(UUID().uuidString).png")

        let workflow = buildImg2ImgWorkflow(request, inputImageName: imageName)
        let promptData = try JSONSerialization.data(withJSONObject: [
            "prompt": workflow,
            "client_id": clientId
        ])

        let responseData = try await post("/prompt", body: promptData)

        guard let responseJSON = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let promptId = responseJSON["prompt_id"] as? String else {
            throw BackendError.decodingFailed("No prompt_id in response")
        }

        let images = try await pollForImages(promptId: promptId)

        let generationTime = Date().timeIntervalSince(startTime)
        let metadata = GenerationMetadata(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            steps: request.steps,
            samplerName: request.samplerName,
            cfgScale: request.cfgScale,
            width: request.width,
            height: request.height,
            seed: request.seed,
            backendName: "ComfyUI",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    // MARK: - Cancel

    func cancel() async throws {
        _ = try await post("/interrupt", body: Data())
    }

    // MARK: - Workflow Building

    private func buildTxt2ImgWorkflow(_ request: ImageGenerationRequest) -> [String: Any] {
        return [
            "3": [
                "class_type": "KSampler",
                "inputs": [
                    "seed": request.seed == -1 ? Int.random(in: 0...Int(Int32.max)) : request.seed,
                    "steps": request.steps,
                    "cfg": request.cfgScale,
                    "sampler_name": mapSamplerName(request.samplerName),
                    "scheduler": "normal",
                    "denoise": 1.0,
                    "model": ["4", 0],
                    "positive": ["6", 0],
                    "negative": ["7", 0],
                    "latent_image": ["5", 0]
                ] as [String : Any]
            ] as [String : Any],
            "4": [
                "class_type": "CheckpointLoaderSimple",
                "inputs": ["ckpt_name": "v1-5-pruned-emaonly.safetensors"]
            ],
            "5": [
                "class_type": "EmptyLatentImage",
                "inputs": [
                    "width": request.width,
                    "height": request.height,
                    "batch_size": request.batchSize
                ] as [String : Any]
            ] as [String : Any],
            "6": [
                "class_type": "CLIPTextEncode",
                "inputs": [
                    "text": request.prompt,
                    "clip": ["4", 1]
                ] as [String : Any]
            ] as [String : Any],
            "7": [
                "class_type": "CLIPTextEncode",
                "inputs": [
                    "text": request.negativePrompt,
                    "clip": ["4", 1]
                ] as [String : Any]
            ] as [String : Any],
            "8": [
                "class_type": "VAEDecode",
                "inputs": [
                    "samples": ["3", 0],
                    "vae": ["4", 2]
                ] as [String : Any]
            ] as [String : Any],
            "9": [
                "class_type": "SaveImage",
                "inputs": [
                    "filename_prefix": "AIStudio",
                    "images": ["8", 0]
                ] as [String : Any]
            ] as [String : Any]
        ]
    }

    private func buildImg2ImgWorkflow(_ request: ImageToImageRequest, inputImageName: String) -> [String: Any] {
        return [
            "1": [
                "class_type": "LoadImage",
                "inputs": ["image": inputImageName]
            ],
            "2": [
                "class_type": "VAEEncode",
                "inputs": [
                    "pixels": ["1", 0],
                    "vae": ["4", 2]
                ] as [String : Any]
            ] as [String : Any],
            "3": [
                "class_type": "KSampler",
                "inputs": [
                    "seed": request.seed == -1 ? Int.random(in: 0...Int(Int32.max)) : request.seed,
                    "steps": request.steps,
                    "cfg": request.cfgScale,
                    "sampler_name": mapSamplerName(request.samplerName),
                    "scheduler": "normal",
                    "denoise": request.denoisingStrength,
                    "model": ["4", 0],
                    "positive": ["6", 0],
                    "negative": ["7", 0],
                    "latent_image": ["2", 0]
                ] as [String : Any]
            ] as [String : Any],
            "4": [
                "class_type": "CheckpointLoaderSimple",
                "inputs": ["ckpt_name": "v1-5-pruned-emaonly.safetensors"]
            ],
            "6": [
                "class_type": "CLIPTextEncode",
                "inputs": [
                    "text": request.prompt,
                    "clip": ["4", 1]
                ] as [String : Any]
            ] as [String : Any],
            "7": [
                "class_type": "CLIPTextEncode",
                "inputs": [
                    "text": request.negativePrompt,
                    "clip": ["4", 1]
                ] as [String : Any]
            ] as [String : Any],
            "8": [
                "class_type": "VAEDecode",
                "inputs": [
                    "samples": ["3", 0],
                    "vae": ["4", 2]
                ] as [String : Any]
            ] as [String : Any],
            "9": [
                "class_type": "SaveImage",
                "inputs": [
                    "filename_prefix": "AIStudio_img2img",
                    "images": ["8", 0]
                ] as [String : Any]
            ] as [String : Any]
        ]
    }

    private func mapSamplerName(_ name: String) -> String {
        // Map A1111-style sampler names to ComfyUI names
        let mapping: [String: String] = [
            "Euler a": "euler_ancestral",
            "Euler": "euler",
            "DPM++ 2M": "dpmpp_2m",
            "DPM++ 2M Karras": "dpmpp_2m",
            "DPM++ SDE": "dpmpp_sde",
            "DPM++ SDE Karras": "dpmpp_sde",
            "DDIM": "ddim",
            "UniPC": "uni_pc",
        ]
        return mapping[name] ?? name.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    // MARK: - Polling & Image Retrieval

    private func pollForImages(promptId: String, maxAttempts: Int = 300) async throws -> [GeneratedImage] {
        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            let data = try await get("/history/\(promptId)")
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let promptHistory = json[promptId] as? [String: Any],
                  let outputs = promptHistory["outputs"] as? [String: Any] else {
                continue
            }

            // Find the SaveImage node output
            for (_, nodeOutput) in outputs {
                guard let output = nodeOutput as? [String: Any],
                      let imageInfos = output["images"] as? [[String: Any]] else {
                    continue
                }

                var images: [GeneratedImage] = []
                for (index, imageInfo) in imageInfos.enumerated() {
                    guard let filename = imageInfo["filename"] as? String,
                          let subfolder = imageInfo["subfolder"] as? String else {
                        continue
                    }

                    let imageData = try await getImage(filename: filename, subfolder: subfolder)
                    if ImageUtils.validateImageData(imageData) {
                        images.append(GeneratedImage(imageData: imageData, index: index))
                    }
                }

                if !images.isEmpty {
                    return images
                }
            }
        }

        throw BackendError.timeout
    }

    private func getImage(filename: String, subfolder: String) async throws -> Data {
        var components = URLComponents(string: "\(baseURL)/view")!
        components.queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "subfolder", value: subfolder),
            URLQueryItem(name: "type", value: "output")
        ]
        guard let url = components.url else {
            throw BackendError.invalidURL("Failed to build view URL")
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed(0, "Failed to download image")
        }
        return data
    }

    private func uploadImage(_ data: Data, filename: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/upload/image") else {
            throw BackendError.invalidURL("\(baseURL)/upload/image")
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed(0, "Failed to upload image")
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let name = json["name"] as? String else {
            throw BackendError.decodingFailed("No name in upload response")
        }

        return name
    }

    // MARK: - HTTP Helpers

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendError.invalidURL("\(baseURL)\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw BackendError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0, body)
        }
        return data
    }

    private func post(_ path: String, body: Data) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendError.invalidURL("\(baseURL)\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 300
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw BackendError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0, body)
        }
        return data
    }
}
