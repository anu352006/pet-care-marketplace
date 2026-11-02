package com.petcare.marketplace.service;

import com.petcare.marketplace.dto.AuthRequest;
import com.petcare.marketplace.dto.AuthResponse;
import com.petcare.marketplace.dto.RegisterRequest;
import com.petcare.marketplace.entity.Provider;
import com.petcare.marketplace.entity.User;
import com.petcare.marketplace.repository.ProviderRepository;
import com.petcare.marketplace.repository.UserRepository;
import com.petcare.marketplace.security.JwtUtils;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtUtils jwtUtils;

    public AuthService(UserRepository userRepository,
                       ProviderRepository providerRepository,
                       PasswordEncoder passwordEncoder,
                       AuthenticationManager authenticationManager,
                       JwtUtils jwtUtils) {
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtUtils = jwtUtils;
    }

    public AuthResponse authenticate(AuthRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("User not found: " + request.getEmail()));

        String token = jwtUtils.generateToken(user.getEmail(), user.getRole().name());

        return new AuthResponse(
                token,
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                user.getRole().name(),
                user.getCity(),
                user.getAvatarUrl()
        );
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("An account with email " + request.getEmail() + " already exists.");
        }

        // Academic requirement: Do not allow public self-registration as ADMIN
        User.Role role = User.Role.PET_OWNER;
        if ("SERVICE_PROVIDER".equalsIgnoreCase(request.getRole())) {
            role = User.Role.SERVICE_PROVIDER;
        }

        User user = new User(
                request.getEmail(),
                passwordEncoder.encode(request.getPassword()),
                request.getName(),
                request.getPhone(),
                role,
                request.getCity() != null ? request.getCity() : "Bengaluru",
                "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80"
        );

        User savedUser = userRepository.save(user);

        // If registered as service provider, create their provider profile
        if (role == User.Role.SERVICE_PROVIDER) {
            Provider provider = new Provider();
            provider.setUser(savedUser);
            provider.setBusinessName(request.getBusinessName() != null ? request.getBusinessName() : savedUser.getFullName() + "'s Pet Services");
            provider.setCity(savedUser.getCity());
            provider.setArea("Central");
            provider.setVerified(false); // Awaits admin verification
            providerRepository.save(provider);
        }

        String token = jwtUtils.generateToken(savedUser.getEmail(), savedUser.getRole().name());

        return new AuthResponse(
                token,
                savedUser.getId(),
                savedUser.getFullName(),
                savedUser.getEmail(),
                savedUser.getRole().name(),
                savedUser.getCity(),
                savedUser.getAvatarUrl()
        );
    }
}
